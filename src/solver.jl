"""
    AbstractSolver
Abstract type to encapsulate the different solver types such as `Solver` or `_SubSolver`.
"""
abstract type AbstractSolver end

"""
    _SubSolver <: AbstractSolver

An internal solver type called by Solver when multithreading is enabled.

# Arguments:
- `id::Int`: subsolver id for debugging
- `model::Model`: a ref to the model of the main solver
- `state::_State`: a `deepcopy` of the main solver that evolves independently
- `settings::Settings`: a ref to the settings of the main solver
"""
struct _SubSolver <: AbstractSolver
    id::Int
    model::Model
    state::_State
    settings::Settings
end

"""
    Solver <: AbstractSolver

Main solver. Handle the solving of a model, and optional multithreaded and/or distributed subsolvers.

# Arguments:
- `model::Model`: A formal description of the targeted problem
- `state::_State`: An internal state to store the info necessary to a solving run
- `settings::Settings`: User settings for this solver
- `subs::Vector{_SubSolver}`: Optional subsolvers
"""
mutable struct Solver <: AbstractSolver
    model::Model
    state::_State
    settings::Settings
    subs::Vector{_SubSolver}
end

"""
    _SubSolver(ms::Solver, id)
Internal structure used in multithreading and distributed version of the solvers. It is only created at the start of a `solve!` run. Its behaviour regarding to sharing information is determined by the main `Solver`.
"""
_SubSolver(ms::Solver, id) = _SubSolver(id, ms.model, deepcopy(ms.state), ms.settings)

"""
    Solver{T}(m::Model; values::Dictionary{Int,T}=Dictionary{Int,T}()) where T <: Number
    Solver{T}(;
        variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),
        constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),
        objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),
        values::Dictionary{Int,T}=Dictionary{Int,T}(),
    ) where T <: Number

Constructor for a solver. Optional starting values can be provided.

```julia
# Model a sudoku model of size 4×4
m = sudoku(2)

# Create a solver instance with variables taking integral values
s = Solver{Int}(m)

# Solver with an empty model to be filled later and expected Float64 values
s = Solver{Float64}()

# Construct a solver from a sets of constraints, objectives, and variables.
s = Solver{Int}(
    variables = get_constraints(m),
    constraints = get_constraints(m),
    objectives = get_objectives(m)
)
```
"""
function Solver(
    m::Model,
    settings::Settings=Settings();
    values::Dictionary{Int,T}=Dictionary{Int,Number}(),
) where T <: Number
    vars, cons = zeros(Float64, get_variables(m)), zeros(Float64, get_constraints(m))
    val, tabu = zero(Float64), Dictionary{Int,Int}()
    state = _State(values, vars, cons, val, tabu, false, copy(values), nothing)
    _make_settings!(settings)
    subs = Vector{_SubSolver}()
    Solver(m, state, settings, subs)
end

function Solver(;
    variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),
    constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),
    objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),
    values::Dictionary{Int,T}=Dictionary{Int,Number}(),
) where T <: Number
    m = Model(; vars=variables, cons=constraints, objs=objectives)
    Solver(m; values=values)
end

# Forwards from model field
@forward AbstractSolver.model get_constraints, get_objectives, get_variables
@forward AbstractSolver.model get_constraint, get_objective, get_variable, get_domain
@forward AbstractSolver.model get_cons_from_var, get_vars_from_cons
@forward AbstractSolver.model add!, add_value!, add_var_to_cons!
@forward AbstractSolver.model delete_value!, delete_var_from_cons!
@forward AbstractSolver.model draw, constriction, describe, is_sat, is_specialized
@forward AbstractSolver.model length_var, length_cons, length_vars, length_objs
@forward AbstractSolver.model constraint!, objective!, variable!
@forward AbstractSolver.model _neighbours, get_name, _is_empty

# Forwards from state field
@forward AbstractSolver.state _cons_costs, _vars_costs, _values, _tabu
@forward AbstractSolver.state _cons_costs!, _vars_costs!, _values!, _tabu!
@forward AbstractSolver.state _cons_cost, _var_cost, _value
@forward AbstractSolver.state _cons_cost!, _var_cost!, _value!
@forward AbstractSolver.state _decrease_tabu!, _delete_tabu!, _decay_tabu!, _length_tabu
@forward AbstractSolver.state _set!, _swap_value!, _insert_tabu!, _empty_tabu!
@forward AbstractSolver.state _optimizing, _optimizing!, _satisfying!
@forward AbstractSolver.state _best!, _best, _select_worse, _solution
@forward AbstractSolver.state _error, _error!

# Forward from utils.jl (settings)
@forward AbstractSolver.settings _verbose, Base.get!

specialize!(s) = s.model = specialize(s.model)

"""
    setting(s, sym::Symbol)

Retrieve a specific setting `sym` of solver `s`.
"""
setting(s, sym::Symbol) = s.settings[sym]

"""
    _draw!(s)

Draw a random (re-)starting configuration.
"""
function _draw!(s)
    foreach(x -> _set!(s, x, draw(s, x)), keys(get_variables(s)))
end

"""
    _compute_cost!(s, ind, c)

Compute the cost of constraint `c` with index `ind`.
"""
function _compute_cost!(s, ind, c)
    old_cost = _cons_cost(s, ind)
    new_cost = c.f(map(x -> _value(s, x), c.vars))
    _cons_cost!(s, ind, new_cost)
    # _up_error!(s, old_cost, new_cost) TODO: make it right
    foreach(x -> _var_cost!(s, x, _var_cost(s, x) + new_cost - old_cost), c.vars)
end

"""
    _compute_costs!(s; cons_lst::Indices{Int} = Indices{Int}())

Compute the cost of constraints `c` in `cons_lst`. If `cons_lst` is empty, compute the cost for all the constraints in `s`.
"""
function _compute_costs!(s; cons_lst=Indices{Int}())
    if isempty(cons_lst)
        foreach(((id, c),) -> _compute_cost!(s, id, c), pairs(get_constraints(s)))
    else
        foreach(
            ((id, c),) -> _compute_cost!(s, id, c),
            pairs(view(get_constraints(s), cons_lst))
        )
    end
    _error!(s, sum(_cons_costs(s)))
end

"""
    _compute_objective!(s, o::Objective)
    _compute_objective!(s, o = 1)

Compute the objective `o`'s value.
"""
_compute_objective!(s, o::Objective) = _best!(s, o.f(_values(s).values))
_compute_objective!(s, o=1) = _compute_objective!(s, get_objective(s, o))

"""
    _compute!(s; o::Int = 1, cons_lst = Indices{Int}())

Compute the objective `o`'s value if `s` is satisfied and return the current `error`.

# Arguments:
- `s`: a solver
- `o`: targeted objective
- `cons_lst`: list of targeted constraints, if empty compute for the whole set
"""
function _compute!(s; o::Int=1, cons_lst=Indices{Int}())
    _compute_costs!(s, cons_lst=cons_lst)
    (sat = _error(s) == 0.0) && _optimizing(s) && _compute_objective!(s, o)
    return sat
end

"""
    _move!(s, x::Int, dim::Int = 0)

Perform an improving move in `x` neighbourhood if possible.

# Arguments:
- `s`: a solver of type S <: AbstractSolver
- `x`: selected variable id
- `dim`: describe the dimension of the considered neighbourhood
"""
function _move!(s, x::Int, dim::Int=0)
    best_values = [begin old_v = _value(s, x) end]; best_swap = [x]
    tabu = true # unless proved otherwise, this variable is now tabu
    best_cost = old_cost = _error(s)
    old_vars_costs = copy(_vars_costs(s))
    old_cons_costs = copy(_cons_costs(s))
    for v in _neighbours(s, x, dim)
        dim == 0 && v == old_v && continue
        dim == 0 ? _value!(s, x, v) : _swap_value!(s, x, v)

        _verbose(s, "Compute costs: selected var(s) x_$x " * (dim == 0 ? "= $v" : "⇆ x_$v"))

        cons_x_v = union(get_cons_from_var(s, x), dim == 0 ? [] : get_cons_from_var(s, v))
        _compute!(s, cons_lst=cons_x_v)

        cost = _error(s)
        if cost < best_cost
            _verbose(s, "cost = $cost < $best_cost")
            tabu = false
            best_cost = cost
            dim == 0 ? best_values = [v] : best_swap = [v]
        elseif cost == best_cost
            _verbose(s, "cost = best_cost = $cost")
            push!(dim == 0 ? best_values : best_swap, v)
        end

        # _verbose(s, "")
        _vars_costs!(s, copy(old_vars_costs))
        _cons_costs!(s, copy(old_cons_costs))
        _error!(s, old_cost)

        # swap/change back the value of x (and y/)
        dim == 0 ? _value!(s, x, old_v) : _swap_value!(s, x, v)
    end
    return best_values, best_swap, tabu
end

"""
    _init_solve!(s::S) where S <: AbstractSolver

Initialize a solver in both sequential and parallel contexts.
"""
_init_solve!(ss::_SubSolver) = (_draw!(ss); _compute!(ss))
function _init_solve!(s::Solver)
    # Specialized the model if specialize = true (and not already done)
    !is_specialized(s) && setting(s, :specialize) && specialize!(s)
    _verbose(s, describe(s.model))
    _verbose(s, "Starting solver")

    # draw initial values unless provided and set best_values
    isempty(_values(s)) && _draw!(s)
    _verbose(s, "Initial values = $(_values(s))")

    # compute initial constraints and variables costs
    sat = _compute!(s)
    _verbose(s, "Initial constraints costs = $(s.state.cons_costs)")
    _verbose(s, "Initial variables costs = $(s.state.vars_costs)")

    # Tabu times
    get!(s, :tabu_time, length_vars(s) ÷ 2) # 10?
    get!(s, :local_tabu, setting(s, :tabu_time) ÷ 2)
    get!(s, :δ_tabu, setting(s, :tabu_time) - setting(s, :local_tabu))# 20-30

    # Create sub solvers
    foreach(id -> push!(s.subs, _SubSolver(s, id)), 2:nthreads())

    return sat
end

"""
    _restart!(s, k = 10)

Restart a solver.
"""
function _restart!(s, k=10)
    _verbose(s, "\n============== RESTART!!!!================\n")
    _draw!(s)
    _empty_tabu!(s)
    δ = ((k - 1) * setting(s, :δ_tabu) + setting(s, :tabu_time)) / k
    push!(s.settings, :δ_tabu => δ)
    _optimizing(s) && _satisfying!(s)
end

"""
    _check_restart(s)

Check if a restart of `s` is necessary. If `s` has subsolvers, this check is independent for all of them.
"""
function _check_restart(s)
    return rand() ≤ (_length_tabu(s) - setting(s, :δ_tabu)) / setting(s, :local_tabu)
end

"""
    _step!(s)

Iterate a step of the solver run.
"""
function _step!(s)
    # select worst variables
    x = _select_worse(s)
    _verbose(s, "Selected x = $x")

    # Local move (change the value of the selected variable)
    best_values, best_swap, tabu = _move!(s, x)
    # _compute!(s)

    # If local move is bad (tabu), then try permutation
    if tabu
        _, best_swap, tabu = _move!(s, x, 1)
        _compute!(s)
    else # compute the costs changes from best local move
        _compute!(s; cons_lst=get_cons_from_var(s, x))
    end

    # decay tabu list
    _decay_tabu!(s)

    # update tabu list with either worst or selected variable
    _insert_tabu!(s, x, tabu ? setting(s, :tabu_time) : setting(s, :local_tabu))
    _verbose(s, "Tabu list: $(_tabu(s))")

    # Select the best move (value or swap)
    if x ∈ best_swap
        _value!(s, x, rand(best_values))
        _verbose(s, "best_values: $best_values")
    else
        _swap_value!(s, x, rand(best_swap))
        _verbose(s, "best_swap : $best_swap")
    end

    # Compute costs and possibly evaluate objective functions
    # return true if a solution for sat is found
    if _compute!(s)
        !is_sat(s) ? _optimizing!(s) : return true
    end

    # Restart if necessary
    _check_restart(s) && _restart!(s)

    return false # no satisfying configuration or optimizing
end

"""
    _check_subs(s)

Check if any subsolver of a main solver `s`, for
- *Satisfaction*, has a solution, then return it, resume the run otherwise
- *Optimization*, has a better solution, then assign it to its internal state
"""
function _check_subs(s)
    if is_sat(s)
        for (id, ss) in enumerate(s.subs)
            _error(ss) == 0.0 && return id
        end
    else
        for (id, ss) in enumerate(s.subs)
            bs, bss = _best(s), _best(ss)
            isnothing(bs) && (isnothing(bss) ? continue : return id)
            isnothing(bss) ? continue : (bss < bs && return id)
        end
    end
    return 0
end

"""
    _solve!(s, stop)

Start a solving run of a subsolver with a shared `Atomic` boolean stop.
"""
function _solve!(s, stop)
    sat = is_sat(s)
    _init_solve!(s)
    while !(stop[])
        _step!(s) && sat && break
    end
end

"""
    solve!(s; max_iteration=1000, verbose::Bool=false)
Run the solver until a solution is found or `max_iteration` is reached.
`verbose=true` will print out details of the run.

```julia
# Simply run the solver with default max_iteration
solve!(s)

# Run indefinitely the solver with verbose behavior.
solve!(s, max_iteration = Inf, verbose = true)
```
"""
function solve!(s)
    iter = 0
    sat = is_sat(s)
    stop = Atomic{Bool}(false)
    _init_solve!(s) && (sat ? (iter = typemax(0)) : _optimizing!(s))
    @threads for id in 1:min(nthreads(), setting(s, :threads))
        if id == 1
            while iter < setting(s, :iteration)
                iter += 1
                _verbose(s, "\n\tLoop $(iter) ($(_optimizing(s) ? "optimization" : "satisfaction"))")
                _step!(s) && sat && break
                _verbose(s, "vals: $(length(_values(s)) > 0 ? _values(s) : nothing)")
                best_sub = _check_subs(s)
                if best_sub > 0
                    bs = s.subs[best_sub]
                    sat && (_values!(s, _values(bs)); break)
                    _best!(s, _best(bs), solution(bs))
                end
            end
            atomic_or!(stop, true)
        else
            _solve!(s.subs[id - 1], stop)
        end
    end
end

"""
    solution(s)

Return the only/best known solution of a satisfaction/optimization model.
"""
solution(s) = is_sat(s) ? _values(s) : _solution(s)
