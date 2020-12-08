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
    p::Problem;
    values::Dictionary{Int,T}=Dictionary{Int,Number}(),
    settings::Settings = Settings(),
) where T <: Number
    vars, cons = zeros(Float64, get_variables(p)), zeros(Float64, get_constraints(p))
    state = _State(values, vars, cons, Dictionary{Int,Int}())
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
@forward Solver.state _set!, _swap_value!, _insert_tabu!

# Forward from utils.jl (settings)
@forward Solver.settings _verbose, Base.get!

# Replace the problem field by its specialized version
function specialize!(s::Solver)
    s.problem = specialize(s.problem)
end

setting(s::Solver, sym::Symbol) = s.settings[sym]

## Internal to solve! function
function _draw!(s::Solver)
    foreach(x -> _set!(s, x, draw(s, x)), keys(get_variables(s)))
end

# Compute costs functions
function _compute_cost!(s::Solver, ind::Int, c::Constraint)
    old_cost = _cons_cost(s, ind)
    new_cost = c.f(map(x -> _value(s, x), c.vars)...)
    _cons_cost!(s, ind, new_cost)
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
end

# rand argmax # TODO: move it somewhere else ?
function _find_rand_argmax(d::DictionaryView{Int,Float64})
    max = -Inf
    argmax = Vector{Int}()
    for (k, v) in pairs(d)
        if v > max
            max = v
            argmax = [k]
        elseif v == max
            push!(argmax, k)
        end
    end
    # println("argmax : $argmax\n") # TODO: verbose/log
    return rand(argmax)
end

# Local move
function _local_move!(s::Solver, x::Int)
    old_v = _value(s, x)
    old_cost = sum(_cons_costs(s))

    best_values = [old_v]
    tabu = true
    for v in get_domain(s, x)
        if v == old_v
            continue
        end
        # change the value of x
        _value!(s, x, v)

        # compute costs over constraints and variables involved by the changes of x
        _verbose(s, "Compute constraints and variables cost: selected variable x_$x = $v")
        old_vars_costs = copy(_vars_costs(s))
        old_cons_costs = copy(_cons_costs(s))
        _compute_costs!(s; cons_lst=get_cons_from_var(s, x))
        # _verbose("values: " * string(values(s)), verbose)
        # _verbose("variables costs = $(vars_cost(s))", verbose)
        # _verbose("constraints costs = $(cons_cost(s))", verbose)
        # _print_sudoku(s)
        cost = sum(_cons_costs(s))
        if cost < old_cost
            _verbose(s, "cost = $cost, old = $old_cost")
            tabu = false
            old_cost = cost
            best_values = [v]
        elseif cost == old_cost
            _verbose(s, "cost = old_cost = $cost")
            old_cost = cost
            push!(best_values, v)
        end
        _verbose(s, "")
        _vars_costs!(s, old_vars_costs)
        _cons_costs!(s, old_cons_costs)
    end
    return best_values, tabu
end

function _permutation_move!(s::Solver, x::Int)
    old_cost = sum(_cons_costs(s))

    best_swap = [x]
    tabu = true
    for y in _neighbours(s, x)
        # swap the value of x and y
        _swap_value!(s, x, y)

        # compute costs over constraints and variables involved by the changes of x
        _verbose(s,
            "Compute constraints and variables cost: selected variables x_$x ⇆ x_$y")
        old_vars_costs = copy(_vars_costs(s))
        old_cons_costs = copy(_cons_costs(s))
        cons_x_y = union(get_cons_from_var(s, x), get_cons_from_var(s, y))
        _compute_costs!(s; cons_lst=cons_x_y)
        # _verbose("values: " * string(values(s)), verbose)
        # _verbose("variables costs = $(vars_cost(s))", verbose)
        # _verbose("constraints costs = $(cons_cost(s))", verbose)
        # _print_sudoku(s)
        cost = sum(_cons_costs(s))
        if cost < old_cost
            _verbose(s, "cost = $cost, old = $old_cost")
            tabu = false
            old_cost = cost
            best_swap = [y]
        elseif cost == old_cost
            _verbose(s, "cost = old_cost = $cost")
            old_cost = cost
            push!(best_swap, y)
        end
        _verbose(s, "")
        _vars_costs!(s, old_vars_costs)
        _cons_costs!(s, old_cons_costs)

        # swap back the value of x and y
        _swap_value!(s, x, y)
    end
    return best_swap, tabu
end

function _init_solve!(s::Solver)
    # Speciliazed the problem if specialize = true (and not already done)
    !is_specialized(s) && setting(s, :specialize) && specialize!(s)
    _verbose(s, describe(s.problem))
    _verbose(s, "Starting solver")

    # draw initial values unless provided and set best_values
    isempty(_values(s)) && _draw!(s)
    _verbose(s, "Initial values = ")

    # compute initial constraints and variables costs
    _compute_costs!(s)
    _verbose(s, "Initial constraints costs = $(s.state.cons_costs)")
    _verbose(s, "Initial variables costs = $(s.state.vars_costs)")

    # Tabu times
    get!(s, :tabu_time, length_vars(s) ÷ 2) # 10?
    get!(s, :local_tabu, setting(s, :tabu_time) ÷ 2)
    get!(s, :δ_tabu, setting(s, :tabu_time) - setting(s, :local_tabu))# 20-30
    return nothing
end

function _sat_step!(s::Solver)
# TODO rewrite with check on each var if > 0.0

    # Restart if stuck in a local minima # TODO: restart optimal
    if rand() ≤ max(0, (_length_tabu(s) - setting(s, :local_tabu)) / setting(s, :δ_tabu))
        _verbose(s, "\n============== RESTART!!!!================\n")
        _draw!(s)
    end

    _compute_costs!(s)

    # _verbose("Initial constraints costs = $(s.state.cons_costs)", verbose)
    # _verbose("Initial variables costs = $(s.state.vars_costs)", verbose)
    # _verbose("values: " * string(values(s)), verbose)
    # _print_sudoku(s)
    if sum(_cons_costs(s)) == 0.0
        return true # a solution has been found
    end
    _verbose(s, "Tabu list: $(_tabu(s))")

    # select worst variables
    nontabu = setdiff(keys(_vars_costs(s)), keys(_tabu(s)))
    x = _find_rand_argmax(view(_vars_costs(s), nontabu))
    _verbose(s, "Selected x = $x")

    # Local move (change the value of the selected variable)
    best_values, tabu = _local_move!(s, x)

    # If local move is bad (tabu), then try permutation
    best_swap = Vector{Int}()
    if tabu
        best_swap, tabu = _permutation_move!(s, x)
        _compute_costs!(s)
    else
        _compute_costs!(s; cons_lst=get_cons_from_var(s, x))
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
    return false # no satisfying configuration
end

function _satisfy!(s::Solver)
    sat_loop = 0
    while sat_loop < setting(s, :iteration)
        sat_loop += 1
        _verbose(s, "\n\n\tLoop $sat_loop")
        _sat_step!(s) && break 
    end
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
    # TODO: rewrite with satisfy! and optimize!
    _init_solve!(s)
    _satisfy!(s)
    !is_sat(s)
end
