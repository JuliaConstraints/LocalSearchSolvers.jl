"""
    AbstractSolver
Abstract type to encapsulate the different solver types such as `Solver` or `_SubSolver`.
"""
abstract type AbstractSolver end

meta_id(s) = s.meta_local_id[1]
local_id(s) = s.meta_local_id[2]

"""
Abstract type to encapsulate all solver types that manages other solvers.
"""
abstract type MetaSolver <: AbstractSolver end

"""
    _SubSolver <: AbstractSolver

An internal solver type called by MetaSolver when multithreading is enabled.

# Arguments:
- `id::Int`: subsolver id for debugging
- `model::Model`: a ref to the model of the main solver
- `state::_State`: a `deepcopy` of the main solver that evolves independently
- `options::Options`: a ref to the options of the main solver
"""
mutable struct _SubSolver <: AbstractSolver
    meta_id::Tuple{Int, Int}
    model::_Model
    options::Options
    pool::Pool
    state::State
    strategies::MetaStrategy
end

"""
    LeadSolver <: MetaSolver
Solver managed remotely by a MainSolver. Can manage its own set of local sub solvers.
"""
mutable struct LeadSolver <: MetaSolver
    meta_id::Tuple{Int, Int}
    model::_Model
    options::Options
    pool::Pool
    state::State
    strategies::MetaStrategy
    subs::Vector{_SubSolver}
end

"""
    MainSolver <: AbstractSolver

Main solver. Handle the solving of a model, and optional multithreaded and/or distributed subsolvers.

# Arguments:
- `model::Model`: A formal description of the targeted problem
- `state::_State`: An internal state to store the info necessary to a solving run
- `options::Options`: User options for this solver
- `subs::Vector{_SubSolver}`: Optional subsolvers
"""
mutable struct MainSolver <: MetaSolver
    meta_local_id::Tuple{Int, Int}
    model::_Model
    options::Options
    pool::Pool
    remotes::Vector{LeadSolver} # TODO: make a fitting struct for remote LeadSolver
    state::State
    strategies::MetaStrategy
    subs::Vector{_SubSolver}
end

make_id(::Int, id, ::Val{:lead}) = (id, 0)
make_id(meta, id, ::Val{:sub}) = (meta, id)

"""
    _SubSolver(ms::Solver, id)
Internal structure used in multithreading and distributed version of the solvers. It is only created at the start of a `solve!` run. Its behaviour regarding to sharing information is determined by the main `Solver`.
"""
function solver(mlid, model, options, pool, strats, ::Val{:lead})
    return LeadSolver(mlid, model, options, pool, state(), strats, Vector{_SubSolver}())
end

function solver(mlid, model, options, pool, strats, ::Val{:sub})
    return _SubSolver(mlid, model, options, pool, state(), strats)
end
function solver(ms, id, role; pool = pool(), strats = ms.strategies)
    mlid = make_id(meta_id(ms), id, Val(role))
    return solver(mlid, ms.model, ms.options, pool, strats, Val(role))
end

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
function solver(model = model();
    options = Options(),
    pool = pool(),
    strategies = MetaStrategy(),
)
    mlid = (1, 0)
    remotes = Vector{LeadSolver}()
    subs = Vector{_SubSolver}()
    return MainSolver(mlid, model, options, pool, remotes, state(), strategies, subs)
end

# function solver(::Val{:MOI};
#     variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),
#     constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),
#     objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),
# )
#     m = model(; vars=variables, cons=constraints, objs=objectives)
#     solver(m)
# end

# Forwards from model field
@forward AbstractSolver.model get_constraints, get_objectives, get_variables
@forward AbstractSolver.model get_constraint, get_objective, get_variable, get_domain
@forward AbstractSolver.model get_cons_from_var, get_vars_from_cons, state
@forward AbstractSolver.model add!, add_value!, add_var_to_cons!
@forward AbstractSolver.model delete_value!, delete_var_from_cons!
@forward AbstractSolver.model draw, constriction, describe, is_sat, is_specialized
@forward AbstractSolver.model length_var, length_cons, length_vars, length_objs
@forward AbstractSolver.model constraint!, objective!, variable!
@forward AbstractSolver.model get_name, _is_empty, _inc_cons!, _max_cons, _best_bound
@forward AbstractSolver.model _set_domain!, domain_size, max_domains_size

# Forwards from state field
@forward AbstractSolver.state _cons_costs, _vars_costs, _values, _tabu
@forward AbstractSolver.state _cons_costs!, _vars_costs!, _values!, _tabu!
@forward AbstractSolver.state _cons_cost, _var_cost, _value, set_error!
@forward AbstractSolver.state _cons_cost!, _var_cost!, _value!, get_value, get_values
@forward AbstractSolver.state _set!, _swap_value!
@forward AbstractSolver.state _optimizing, _optimizing!, _satisfying!
@forward AbstractSolver.state _best!, _best, _solution, get_error
@forward AbstractSolver.state _last_improvement, _inc_last_improvement!
@forward AbstractSolver.state _reset_last_improvement!, has_solution

# Forward from options
@forward AbstractSolver.options _verbose, _dynamic, dynamic!, _iteration, _iteration!
@forward AbstractSolver.options _print_level, _print_level!, _solutions, _solutions!
@forward AbstractSolver.options _specialize, _specialize!, _tabu_time, _tabu_time!
@forward AbstractSolver.options _tabu_local, _tabu_local!, _tabu_delta, _tabu_delta!
@forward AbstractSolver.options _threads, _threads!, _time_limit, _time_limit!

# Forwards from pool (of solutions)
@forward AbstractSolver.pool best_config, best_value, best_values

# Forwards from strategies
@forward AbstractSolver.strategies check_restart!
@forward AbstractSolver.strategies decrease_tabu!, delete_tabu!, decay_tabu!
@forward AbstractSolver.strategies length_tabu, insert_tabu!, empty_tabu!, tabu_list

"""
    specialize!(s) = begin

DOCSTRING
"""
specialize!(s) = s.model = specialize(s.model)

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
    new_cost = compute_cost(c, _values(s))
    _cons_cost!(s, ind, new_cost)
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
    set_error!(s, sum(_cons_costs(s)))
end

"""
    _compute_objective!(s, o::Objective)
    _compute_objective!(s, o = 1)

Compute the objective `o`'s value.
"""
function _compute_objective!(s, o::Objective)
    val = apply(o, _values(s).values)
    if is_empty(s.pool) || val < best_value(s)
        s.pool = pool(s.state.configuration)
    end
end
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
    (sat = get_error(s) == 0.0) && _optimizing(s) && _compute_objective!(s, o)
    return sat
end

"""
    _neighbours(s, x, dim = 0)

DOCSTRING

# Arguments:
- `s`: DESCRIPTION
- `x`: DESCRIPTION
- `dim`: DESCRIPTION
"""
function _neighbours(s, x, dim = 0)
    if dim == 0
        return _get_domain(get_domain(s, x)) # TODO: clean the get domain methods
    else
        neighbours = Set{Int}()
        foreach(
            c -> foreach(y ->
                begin
                    b = _value(s, x) ∈ get_variable(s, y) && _value(s, y) ∈ get_variable(s, x)
                    b && push!(neighbours, y)
                end, get_vars_from_cons(s, c)),
            get_cons_from_var(s, x)
        )
        return delete!(neighbours, x)
    end
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
    best_cost = old_cost = get_error(s)
    old_vars_costs = copy(_vars_costs(s))
    old_cons_costs = copy(_cons_costs(s))
    for v in _neighbours(s, x, dim)
        dim == 0 && v == old_v && continue
        dim == 0 ? _value!(s, x, v) : _swap_value!(s, x, v)

        _verbose(s, "Compute costs: selected var(s) x_$x " * (dim == 0 ? "= $v" : "⇆ x_$v"))

        cons_x_v = union(get_cons_from_var(s, x), dim == 0 ? [] : get_cons_from_var(s, v))
        _compute!(s, cons_lst=cons_x_v)

        cost = get_error(s)
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
        set_error!(s, old_cost)

        # swap/change back the value of x (and y/)
        dim == 0 ? _value!(s, x, old_v) : _swap_value!(s, x, v)
    end
    return best_values, best_swap, tabu
end

state!(s) = s.state = state(s) # TODO: add Pool

_init!(s, ::Val{:global}) = !is_specialized(s) && _specialize(s) && specialize!(s)
_init!(s, ::Val{:remote}) = @warn "TODO: implement distributed solvers (LeadSolver)"
_init!(s, ::Val{:meta}) = foreach(id -> push!(s.subs, solver(s, id-1, :sub)), 2:nthreads())
function _init!(s, ::Val{:local}; pool = pool())
    _tabu_time(s) == 0 && _tabu_time!(s, length_vars(s) ÷ 2) # 10?
    _tabu_local(s) == 0 && _tabu_local!(s, _tabu_time(s) ÷ 2)
    _tabu_delta(s) == 0.0 && _tabu_delta!(s, _tabu_time(s) - _tabu_local(s))# 20-30
    state!(s)
    return has_solution(s)
end

# Dispatchers: _init!

_init!(s, role::Symbol) = _init!(s, Val(role))

function _init!(s::MainSolver)
    _init!(s, :global)
    _init!(s, :remote)
    _init!(s, :meta)
    _init!(s, :local)
end

function _init!(s::S) where {S <: MetaSolver}
    _init!(s, :meta)
    _init!(s, :local)
end

_init!(s) = _init!(s, :local)


# """
#     _init_solve!(s::S) where S <: AbstractSolver

# Initialize a solver in both sequential and parallel contexts.
# """
# _init_solve!(ss::_SubSolver) = (_draw!(ss); _compute!(ss))
# function _init_solve!(s::MainSolver)
#     # Specialized the model if specialize = true (and not already done)
#    !is_specialized(s) && _specialize(s) && specialize!(s)
#     _verbose(s, describe(s.model))
#     _verbose(s, "Starting solver")

#     # draw initial values unless provided and set best_values
#     isempty(_values(s)) && _draw!(s)
#     _verbose(s, "Initial values = $(_values(s))")

#     # compute initial constraints and variables costs
#     sat = _compute!(s)
#     _verbose(s, "Initial constraints costs = $(s.state.cons_costs)")
#     _verbose(s, "Initial variables costs = $(s.state.vars_costs)")

#     # Tabu times
#     _tabu_time(s) == 0 && _tabu_time!(s, length_vars(s) ÷ 2) # 10?
#     _tabu_local(s) == 0 && _tabu_local!(s, _tabu_time(s) ÷ 2)
#     _tabu_delta(s) == 0.0 && _tabu_delta!(s, _tabu_time(s) - _tabu_local(s))# 20-30

#     # @info "tabu stuff:" _tabu_time(s) _tabu_local(s) _tabu_delta(s)

#     # Create sub solvers
#     foreach(id -> push!(s.subs, _SubSolver(s, id)), 2:nthreads())

#     return sat
# end

"""
    _restart!(s, k = 10)

Restart a solver.
"""
function _restart!(s, k=10)
    _verbose(s, "\n============== RESTART!!!!================\n")
    _draw!(s)
    empty_tabu!(s)
    δ = ((k - 1) * _tabu_delta(s)) + _tabu_time(s) / k
    _tabu_delta!(s, δ)
    _optimizing(s) && _satisfying!(s)
end

"""
    _check_restart(s)

Check if a restart of `s` is necessary. If `s` has subsolvers, this check is independent for all of them.
"""
function _check_restart(s)
    return _last_improvement(s) > length_vars(s) || check_restart!(s)
end

"""
    _select_worse(s::S) where S <: Union{_State, AbstractSolver}
Within the non-tabu variables, select the one with the worse error .
"""
function _select_worse(s)
    nontabu = setdiff(keys(_vars_costs(s)), keys(tabu_list(s)))
    return _find_rand_argmax(view(_vars_costs(s), nontabu))
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
    decay_tabu!(s)

    # update tabu list with either worst or selected variable
    insert_tabu!(s, x, tabu ? :tabu : :pick)
    _verbose(s, "Tabu list: $(_tabu(s))")

    # Inc last improvement if tabu
    tabu ? _inc_last_improvement!(s) : _reset_last_improvement!(s)

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
            get_error(ss) == 0.0 && return id
        end
    else
        for (id, ss) in enumerate(s.subs)
            bs = is_empty(s.pool) ? nothing : best_value(s)
            bss = is_empty(ss.pool) ? nothing : best_value(ss)
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
    _init!(s)
    while !(stop[])
        _step!(s) && sat && break
    end
end

function status(s)
    e = get_error(s)
    if e == 0.0 # make tolerance
        return is_sat(s) ? :Solved : :LocalOptimum
    else
        return :Infeasible
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
    _init!(s) && (sat ? (iter = typemax(0)) : _optimizing!(s))
    @threads for id in 1:min(nthreads(), _threads(s))
        if id == 1
            while iter < _iteration(s)
                iter += 1
                _verbose(s, "\n\tLoop $(iter) ($(_optimizing(s) ? "optimization" : "satisfaction"))")
                _step!(s) && sat && break
                _verbose(s, "vals: $(length(_values(s)) > 0 ? _values(s) : nothing)")
                best_sub = _check_subs(s)
                if best_sub > 0
                    bs = s.subs[best_sub]
                    sat && (_values!(s, _values(bs)); break)
                    s.pool = bs.pool
                end
            end
            atomic_or!(stop, true)
        else
            _solve!(s.subs[id - 1], stop)
        end
    end
    return status(s)
end

"""
    solution(s)
tabu
Return the only/best known solution of a satisfaction/optimization model.
"""
solution(s) = is_sat(s) ? _values(s) : _solution(s)

"""
    empty!(s::Solver)

DOCSTRING
"""
function empty!(s::MainSolver)
    empty!(s.model)
    s.state = state()
    empty!(s.subs)
end
