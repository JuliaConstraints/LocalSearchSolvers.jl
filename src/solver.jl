struct Solver{T <: Number}
    problem::Problem
    state::_State{T}
end

function Solver{T}(p::Problem; values::Dictionary{Int,T}=Dictionary{Int,T}()
) where T <: Number
    vars, cons = zeros(Float64, get_variables(p)), zeros(Float64, get_constraints(p))
    state = _State(values, vars, cons, Dictionary{Int,Int}())
    Solver{T}(p, state)
end

function Solver{T}(;
    variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),
    constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),
    objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),
    values::Dictionary{Int,T}=Dictionary{Int,T}(),
) where T <: Number
    p = Problem(; variables=variables, constraints=constraints, objectives=objectives)
    Solver{T}(p; values=values)
end

# Forwards from problem field
@forward Solver.problem get_constraints, get_objectives, get_variables
@forward Solver.problem get_constraint, get_objective, get_variable, get_domain
@forward Solver.problem get_cons_from_var, get_vars_from_cons
@forward Solver.problem add!, add_value!, add_var_to_cons!
@forward Solver.problem delete_value!, delete_var_from_cons!
@forward Solver.problem draw, constriction, describe, is_sat
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
    println("argmax : $argmax\n") # TODO: verbose/log
    return rand(argmax)
end

# Local move
function _local_move!(s::Solver, x::Int, verbose::Bool)
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
        _verbose("Compute constraints and variables cost: selected variable x_$x = $v",
            verbose
        )
        old_vars_costs = copy(_vars_costs(s))
        old_cons_costs = copy(_cons_costs(s))
        _compute_costs!(s; cons_lst=get_cons_from_var(s, x))
        # _verbose("values: " * string(values(s)), verbose)
        # _verbose("variables costs = $(vars_cost(s))", verbose)
        # _verbose("constraints costs = $(cons_cost(s))", verbose)
        _print_sudoku(s)
        cost = sum(_cons_costs(s))
        if cost < old_cost
            _verbose("cost = $cost, old = $old_cost", verbose)
            tabu = false
            old_cost = cost
            best_values = [v]
        elseif cost == old_cost
            _verbose("cost = old_cost = $cost", verbose)
            old_cost = cost
            push!(best_values, v)
        end
        _verbose("", verbose)
        _vars_costs!(s, old_vars_costs)
        _cons_costs!(s, old_cons_costs)
    end
    return best_values, tabu
end

function _permutation_move!(s::Solver, x::Int, verbose::Bool)
    old_cost = sum(_cons_costs(s))

    best_swap = [x]
    tabu = true
    for y in _neighbours(s, x)
        # swap the value of x and y
        _swap_value!(s, x, y)

        # compute costs over constraints and variables involved by the changes of x
        _verbose("Compute constraints and variables cost: selected variables x_$x ⇆ x_$y",
            verbose
        )
        old_vars_costs = copy(_vars_costs(s))
        old_cons_costs = copy(_cons_costs(s))
        cons_x_y = union(get_cons_from_var(s, x), get_cons_from_var(s, y))
        _compute_costs!(s; cons_lst=cons_x_y)
        # _verbose("values: " * string(values(s)), verbose)
        # _verbose("variables costs = $(vars_cost(s))", verbose)
        # _verbose("constraints costs = $(cons_cost(s))", verbose)
        _print_sudoku(s)
        cost = sum(_cons_costs(s))
        if cost < old_cost
            _verbose("cost = $cost, old = $old_cost", verbose)
            tabu = false
            old_cost = cost
            best_swap = [y]
        elseif cost == old_cost
            _verbose("cost = old_cost = $cost", verbose)
            old_cost = cost
            push!(best_swap, y)
        end
        _verbose("", verbose)
        _vars_costs!(s, old_vars_costs)
        _cons_costs!(s, old_cons_costs)

        # swap back the value of x and y
        _swap_value!(s, x, y)
    end
    return best_swap, tabu
end

function solve!(s::Solver{T}; max_iteration=1000, verbose::Bool=false) where {T <: Real}
    # if no objectives are provided, the problem is a satisfaction one
    sat = is_sat(s)

    if verbose
        println(describe(s.problem))
    end
    _verbose("Starting solver", verbose)

    # draw initial values unless provided
    if isempty(_values(s))
        _draw!(s)
    end
    _verbose("Initial values = ", verbose) # * string(values(s)), verbose -# )
    _print_sudoku(s)

    # compute initial constraints and variables costs
    _compute_costs!(s)
    # _verbose("Initial constraints costs = $(s.state.cons_costs)", verbose)
    # _verbose("Initial variables costs = $(s.state.vars_costs)", verbose)

    # Tabu times
    tabu_time = length_vars(s) ÷ 2 # 10 ?
    local_tabu_time = tabu_time ÷ 2
    δ_tabu = tabu_time - local_tabu_time # 20-30 %

    count_loop = 0
    # _verbose("Entering loop", verbose)

    # TODO rewrite with check on each var if > 0.0
    while count_loop < max_iteration
        # increase loop counter
        count_loop += 1
        _verbose("\n\n\tLoop $count_loop", verbose)

        # Restart if stuck in a local minima # TODO: restart optimal
        if rand() ≤ max(0, (_length_tabu(s) - local_tabu_time) / δ_tabu)
            _verbose("\n============== RESTART!!!!================\n", verbose)
            _draw!(s)
        end

        _compute_costs!(s)

        # _verbose("Initial constraints costs = $(s.state.cons_costs)", verbose)
        # _verbose("Initial variables costs = $(s.state.vars_costs)", verbose)
        # _verbose("values: " * string(values(s)), verbose)
        _print_sudoku(s)
        if sum(s.state.cons_costs) == 0.0
            break
        end
        _verbose("Tabu list: $(_tabu(s))", verbose)

        # select worst variables
        nontabu = setdiff(keys(_vars_costs(s)), keys(_tabu(s)))
        x = _find_rand_argmax(view(_vars_costs(s), nontabu))
        _verbose("Selected x = $x", verbose)

        # Local move (change the value of the selected variable)
        best_values, tabu = _local_move!(s, x, verbose)

        # If local move is bad (tabu), then try permutation
        best_swap = Vector{Int}()
        if tabu
            best_swap, tabu = _permutation_move!(s, x, verbose)
            _compute_costs!(s)
        else
            _compute_costs!(s; cons_lst=get_cons_from_var(s, x))
        end

        # decay tabu list
        _decay_tabu!(s)

        # update tabu list with either worst or selected variable
        _insert_tabu!(s, x, tabu ? tabu_time : local_tabu_time)
        if isempty(best_swap)
            _value!(s, x, rand(best_values))
        else
            _swap_value!(s, x, rand(best_swap))
        end
    end

end