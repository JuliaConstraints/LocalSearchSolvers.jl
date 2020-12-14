mutable struct Solver
    problem::Problem
    state::_State
    settings::Settings
end

"""
    Solver{T}(p::Problem; values::Dictionary{Int,T}=Dictionary{Int,T}()) where T <: Number
    Solver{T}(;
        variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),
        constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),
        objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),
        values::Dictionary{Int,T}=Dictionary{Int,T}(),
    ) where T <: Number

Constructor for a solver. Optional starting values can be provided.

```julia
# Model a sudoku problem of size 4×4
p = sudoku(2)

# Create a solver instance with variables taking integral values
s = Solver{Int}(p)

# Solver with an empty problem to be filled later and expected Float64 values
s = Solver{Float64}()

# Construct a solver from a sets of constraints, objectives, and variables.
s = Solver{Int}(
    variables = get_constraints(p),
    constraints = get_constraints(p),
    objectives = get_objectives(p)
)
```
"""
function Solver(
    p::Problem,
    settings::Settings=Settings();
    values::Dictionary{Int,T}=Dictionary{Int,Number}(),
) where T <: Number
    vars, cons = zeros(Float64, get_variables(p)), zeros(Float64, get_constraints(p))
    val, tabu = zero(Float64), Dictionary{Int,Int}()
    state = _State(values, vars, cons, val, tabu, false, copy(values), nothing)
    make_settings!(settings)
    Solver(p, state, settings)
end

function Solver(;
    variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),
    constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),
    objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),
    values::Dictionary{Int,T}=Dictionary{Int,Number}(),
) where T <: Number
    p = Problem(; vars=variables, cons=constraints, objs=objectives)
    Solver(p; values=values)
end

# Forwards from problem field
@forward Solver.problem get_constraints, get_objectives, get_variables
@forward Solver.problem get_constraint, get_objective, get_variable, get_domain
@forward Solver.problem get_cons_from_var, get_vars_from_cons
@forward Solver.problem add!, add_value!, add_var_to_cons!
@forward Solver.problem delete_value!, delete_var_from_cons!
@forward Solver.problem draw, constriction, describe, is_sat, is_specialized
@forward Solver.problem length_var, length_cons, length_vars, length_objs
@forward Solver.problem constraint!, objective!, variable!
@forward Solver.problem _neighbours, get_name

# Forwards from state field
@forward Solver.state _cons_costs, _vars_costs, _values, _tabu
@forward Solver.state _cons_costs!, _vars_costs!, _values!, _tabu!
@forward Solver.state _cons_cost, _var_cost, _value
@forward Solver.state _cons_cost!, _var_cost!, _value!
@forward Solver.state _decrease_tabu!, _delete_tabu!, _decay_tabu!, _length_tabu
@forward Solver.state _set!, _swap_value!, _insert_tabu!, _empty_tabu!
@forward Solver.state _optimizing, _optimizing!, _satisfying!, _switch!
@forward Solver.state _best!, _best, _select_worse
@forward Solver.state _error, _error!, _up_error!

# Forward from utils.jl (settings)
@forward Solver.settings _verbose, Base.get!

# Replace the problem field by its specialized version
function specialize!(s::Solver)
    s.problem = specialize(s.problem)
end

setting(s::Solver, sym::Symbol) = s.settings[sym]
# _settings(s::Solver) = s.settings

## Internal to solve! function
function _draw!(s::Solver)
    foreach(x -> _set!(s, x, draw(s, x)), keys(get_variables(s)))
end

# Compute costs functions
function _compute_cost!(s::Solver, ind::Int, c::Constraint)
    old_cost = _cons_cost(s, ind)
    new_cost = c.f(map(x -> _value(s, x), c.vars)...)
    _cons_cost!(s, ind, new_cost)
    # _up_error!(s, old_cost, new_cost) TODO: make it right
    foreach(x -> _var_cost!(s, x, _var_cost(s, x) + new_cost - old_cost), c.vars)
end

function _compute_costs!(s::Solver; cons_lst::Indices{Int}=Indices{Int}())
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

_compute_objective!(s::Solver, o::Objective) = _best!(s, o.f(_values(s).values...))
_compute_objective!(s::Solver, o::Int=1) = _compute_objective!(s, get_objective(s, o))

function _compute!(s::Solver; o::Int=1, cons_lst::Indices{Int}=Indices{Int}())
    _compute_costs!(s, cons_lst=cons_lst)
    _optimizing(s) && _compute_objective!(s, o)
    return _error(s) == 0.0
end

function _move!(s::Solver, x::Int, dim::Int=0)
    best_values = [begin old_v = _value(s, x) end]; best_swap = [x]
    tabu = true # unless proved otherwise, this variable is now tabu
    best_cost = old_cost = _error(s)
    old_vars_costs = copy(_vars_costs(s))
    old_cons_costs = copy(_cons_costs(s))
    for v in _neighbours(s, x, dim)
        dim == 0 && v == old_v && continue
        dim == 0 ? _value!(s, x, v) : _swap_value!(s, x, v)

        _verbose(s, begin
            str = "Compute constraints and variables cost: selected variables x_$x "
            str *= dim == 0 ? "= $v" : "⇆ x_$v"
        end)

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

        # swap back the value of x and y
        dim == 0 || _swap_value!(s, x, v)
    end
    # TODO: check return type consistency
    return dim == 0 ? best_values : best_swap, tabu
end

function _init_solve!(s::Solver)
    # Speciliazed the problem if specialize = true (and not already done)
    !is_specialized(s) && setting(s, :specialize) && specialize!(s)
    _verbose(s, describe(s.problem))
    _verbose(s, "Starting solver")

    # draw initial values unless provided and set best_values
    isempty(_values(s)) && _draw!(s)
    _verbose(s, "Initial values = $(_values(s))")

    # compute initial constraints and variables costs
    _compute!(s)
    _verbose(s, "Initial constraints costs = $(s.state.cons_costs)")
    _verbose(s, "Initial variables costs = $(s.state.vars_costs)")

    # Tabu times
    get!(s, :tabu_time, length_vars(s) ÷ 2) # 10?
    get!(s, :local_tabu, setting(s, :tabu_time) ÷ 2)
    get!(s, :δ_tabu, setting(s, :tabu_time) - setting(s, :local_tabu))# 20-30
    return nothing
end

function _restart!(s::Solver, k=10)
    _verbose(s, "\n============== RESTART!!!!================\n")
    _draw!(s)
    _empty_tabu!(s)
    δ = ((k - 1) * setting(s, :δ_tabu) + setting(s, :tabu_time)) / k
    push!(s.settings, :δ_tabu => δ)
    _optimizing(s) && _satisfying!(s)
end

function _check_restart(s::Solver)
    return rand() ≤ (_length_tabu(s) - setting(s, :δ_tabu)) / setting(s, :local_tabu)
end

function _step!(s::Solver)
    # Restart if necessary
    _check_restart(s) && _restart!(s)

    # Compute costs and possibly evaluate objective functions
    # return true if a solution for sat is found
    # TODO: better than _optimizing!(s) ?
    if _compute!(s)
        !is_sat(s) ? _optimizing!(s) : return true
    end

    # select worst variables
    x = _select_worse(s)
    _verbose(s, "Selected x = $x")

    # Local move (change the value of the selected variable)
    best_values, tabu = _move!(s, x)

    # If local move is bad (tabu), then try permutation
    best_swap = Vector{Int}()
    if tabu
        best_swap, tabu = _move!(s, x, 1)
        _compute!(s)
    else # compute the costs changes from best local move
        _compute!(s; cons_lst=get_cons_from_var(s, x))
    end

    # decay tabu list
    _decay_tabu!(s)

    # update tabu list with either worst or selected variable
    _insert_tabu!(s, x, tabu ? setting(s, :tabu_time) : setting(s, :local_tabu))
    if isempty(best_swap)
        _value!(s, x, rand(best_values))
    else
        _swap_value!(s, x, rand(best_swap))
    end
    _verbose(s, "Tabu list: $(_tabu(s))")

    _error!(s, sum(_cons_costs(s)))

    return false # no satisfying configuration or optimizing
end

"""
    solve!(s::Solver{T}; max_iteration=1000, verbose::Bool=false) where {T <: Real}
Run the solver until a solution is found or `max_iteration` is reached.
`verbose=true` will print out details of the run.

```julia
# Simply run the solver with default max_iteration
solve!(s)

# Run indefinitely the solver with verbose behavior.
solve!(s, max_iteration = Inf, verbose = true)
```
"""
function solve!(s::Solver)
    _init_solve!(s)
    sat = is_sat(s)

    iter = 0
    while iter < setting(s, :iteration)
        iter += 1
        _verbose(s, "\n\tLoop $iter ($(_optimizing(s) ? "optimization" : "satisfaction"))")
        _step!(s) && sat && break
    end
end
