"""
    AbstractSolver
Abstract type to encapsulate the different solver types such as `Solver` or `_SubSolver`.
"""
abstract type AbstractSolver end

# Dummy method to (not) add a TimeStamps to a solver
add_time!(::AbstractSolver, i) = nothing

function solver(ms, id, role; pool = pool(), strats = MetaStrategy(ms))
    mlid = make_id(meta_id(ms), id, Val(role))
    return solver(mlid, ms.model, ms.options, pool, ms.rc_report, ms.rc_sol, ms.rc_stop, strats, Val(role))
end

# Forwards from model field
@forward AbstractSolver.model add!
@forward AbstractSolver.model add_value!
@forward AbstractSolver.model add_var_to_cons!
@forward AbstractSolver.model constraint!
@forward AbstractSolver.model constriction
@forward AbstractSolver.model delete_value!
@forward AbstractSolver.model delete_var_from_cons!
@forward AbstractSolver.model describe
@forward AbstractSolver.model domain_size
@forward AbstractSolver.model draw
@forward AbstractSolver.model get_cons_from_var
@forward AbstractSolver.model get_constraint
@forward AbstractSolver.model get_constraints
@forward AbstractSolver.model get_domain
@forward AbstractSolver.model get_name
@forward AbstractSolver.model get_objective
@forward AbstractSolver.model get_objectives
@forward AbstractSolver.model get_variable
@forward AbstractSolver.model get_variables
@forward AbstractSolver.model get_vars_from_cons
@forward AbstractSolver.model is_sat
@forward AbstractSolver.model is_specialized
@forward AbstractSolver.model length_cons
@forward AbstractSolver.model length_objs
@forward AbstractSolver.model length_var
@forward AbstractSolver.model length_vars
@forward AbstractSolver.model max_domains_size
@forward AbstractSolver.model objective!
@forward AbstractSolver.model sense
@forward AbstractSolver.model sense!
@forward AbstractSolver.model state
@forward AbstractSolver.model update_domain!
@forward AbstractSolver.model variable!
@forward AbstractSolver.model _best_bound
@forward AbstractSolver.model _inc_cons!
@forward AbstractSolver.model _is_empty
@forward AbstractSolver.model _max_cons
@forward AbstractSolver.model _set_domain!

# Forwards from state field
@forward AbstractSolver.state get_error
@forward AbstractSolver.state get_value
@forward AbstractSolver.state get_values
@forward AbstractSolver.state set_error!
@forward AbstractSolver.state set_value!
@forward AbstractSolver.state _best
@forward AbstractSolver.state _best!
@forward AbstractSolver.state _cons_cost
@forward AbstractSolver.state _cons_cost!
@forward AbstractSolver.state _cons_costs
@forward AbstractSolver.state _cons_costs!
@forward AbstractSolver.state _inc_last_improvement!
@forward AbstractSolver.state _last_improvement
@forward AbstractSolver.state _optimizing
@forward AbstractSolver.state _optimizing!
@forward AbstractSolver.state _satisfying!
@forward AbstractSolver.state _set!
@forward AbstractSolver.state _solution
@forward AbstractSolver.state _swap_value!
@forward AbstractSolver.state _reset_last_improvement!
@forward AbstractSolver.state _value
@forward AbstractSolver.state _value!
@forward AbstractSolver.state _values
@forward AbstractSolver.state _values!
@forward AbstractSolver.state _var_cost
@forward AbstractSolver.state _var_cost!
@forward AbstractSolver.state _vars_costs
@forward AbstractSolver.state _vars_costs!

# Forward from options
@forward AbstractSolver.options get_option
@forward AbstractSolver.options set_option!
@forward AbstractSolver.options _verbose

# Forwards from pool (of solutions)
@forward AbstractSolver.pool best_config
@forward AbstractSolver.pool best_value
@forward AbstractSolver.pool best_values
@forward AbstractSolver.pool has_solution

# Forwards from strategies
@forward AbstractSolver.strategies check_restart!
@forward AbstractSolver.strategies decay_tabu!
@forward AbstractSolver.strategies decrease_tabu!
@forward AbstractSolver.strategies delete_tabu!
@forward AbstractSolver.strategies empty_tabu!
@forward AbstractSolver.strategies insert_tabu!
@forward AbstractSolver.strategies length_tabu
@forward AbstractSolver.strategies tabu_list

"""
    specialize!(solver)
Replace the model of `solver` by one with specialized types (variables, constraints, objectives).
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
    val = sense(s) * apply(o, _values(s).values)
    set_value!(s, val)
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
    _compute_costs!(s; cons_lst)
    if get_error(s) == 0.0
        _optimizing(s) && _compute_objective!(s, o)
        is_sat(s) && (s.pool = pool(s.state.configuration))
        return true
    end
    return false
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
        is_discrete = typeof(get_variable(s, x).domain) <: ContinuousDomain
        return is_discrete ? map(_ -> draw(s, x), 1:(length_vars(s)*length_cons(s))) : get_domain(s, x)
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

state!(s) = s.state = state(s)

function _init!(s, ::Val{:global})
    if !is_specialized(s) && get_option(s, "specialize")
        specialize!(s)
        set_option!(s, "specialize", true)
    end
    put!(s.rc_stop, nothing)
    foreach(i -> put!(s.rc_report, nothing), setdiff(workers(), [1]))
end
_init!(s, ::Val{:meta}) = foreach(id -> push!(s.subs, solver(s, id-1, :sub)), 2:nthreads())

function _init!(s, ::Val{:remote})
    for w in setdiff(workers(), [1])
        ls = remotecall(solver, w, s, w, :lead)
        remote_do(set_option!, w, fetch(ls), "print_level", :silent)
        remote_do(set_option!, w, fetch(ls), "threads",remotecall_fetch(Threads.nthreads, w))
        push!(s.remotes, w => ls)
    end
end

function _init!(s, ::Val{:local}; pool = pool())
    get_option(s, "tabu_time") == 0 && set_option!(s, "tabu_time", length_vars(s) ÷ 2) # 10?
    get_option(s, "tabu_local") == 0 && set_option!(s, "tabu_local", get_option(s, "tabu_time") ÷ 2)
    get_option(s, "tabu_delta") == 0 && set_option!(s, "tabu_delta", get_option(s, "tabu_time") - get_option(s, "tabu_local")) # 20-30
    state!(s)
    return has_solution(s)
end

_init!(s, role::Symbol) = _init!(s, Val(role))

"""
    _restart!(s, k = 10)

Restart a solver.
"""
function _restart!(s, k=10)
    _verbose(s, "\n============== RESTART!!!!================\n")
    _draw!(s)
    empty_tabu!(s)
    δ = ((k - 1) * get_option(s, "tabu_delta")) + get_option(s, "tabu_time") / k
    set_option!(s, "tabu_delta", δ)
    _compute!(s) ? _optimizing!(s) : _satisfying!(s)
end

"""
    _check_restart(s)

Check if a restart of `s` is necessary. If `s` has subsolvers, this check is independent for all of them.
"""
function _check_restart(s)
    a = _last_improvement(s) > length_vars(s)
    b = check_restart!(s; tabu_length = length_tabu(s))
    return a || b
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
    copy_to!(s.state.fluct, _cons_costs(s), _vars_costs(s))
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

        if cost == 0 && is_sat(s)
            s.pool == pool(s.state.configuration)
            return best_values, best_swap, tabu
        end

        copy_from!(s.state.fluct, _cons_costs(s), _vars_costs(s))
        set_error!(s, old_cost)

        # swap/change back the value of x (and y/)
        dim == 0 ? _value!(s, x, old_v) : _swap_value!(s, x, v)
    end
    return best_values, best_swap, tabu
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
    _verbose(s, "Tabu list: $(tabu_list(s))")

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
_check_subs(::AbstractSolver) = 0 # Dummy method

"""
    stop_while_loop()
Check the stop conditions of the `solve!` while inner loop.
"""
stop_while_loop(::AbstractSolver) = nothing

"""
    solve_while_loop!(s, )
Search the space of configurations.
"""
function solve_while_loop!(s, stop, sat, iter, st)
    while stop_while_loop(s, stop, iter, st)
        iter += 1
        _verbose(s, "\n\tLoop $(iter) ($(_optimizing(s) ? "optimization" : "satisfaction"))")
        _step!(s) && sat && break
        _verbose(s, "vals: $(length(_values(s)) > 0 ? _values(s) : nothing)")
        best_sub = _check_subs(s)
        if best_sub > 0
            bs = s.subs[best_sub]
            s.pool = deepcopy(bs.pool)
            sat && break
        end
    end
end


"""
    remote_dispatch!(solver)
Starts the `LeadSolver`s attached to the `MainSolver`.
"""
remote_dispatch!(::AbstractSolver) = nothing # dummy method

"""
    solve_for_loop!(solver, stop, sat, iter)
First loop in the solving process that starts `LeadSolver`s from the `MainSolver`, and `_SubSolver`s from each `MetaSolver`.
"""
solve_for_loop!(s, stop, sat, iter, st) = solve_while_loop!(s, stop, sat, iter, st)

function update_pool!(s, pool)
    is_empty(pool) && return nothing
    if is_sat(s) || best_value(s) > best_value(pool)
        s.pool = deepcopy(pool)
    end
end

"""
    remote_stop!!(solver)
Fetch the pool of solutions from `LeadSolvers` and merge it into the `MainSolver`.
"""
remote_stop!(::AbstractSolver) = nothing

"""
    post_process(s::MainSolver)
Launch a serie of tasks to round-up a solving run, for instance, export a run's info.
"""
post_process(::AbstractSolver) = nothing

function solve!(s, stop = Atomic{Bool}(false))
    start_time = time()
    add_time!(s, 1) # only used by MainSolver
    iter = 0 # only used by MainSolver
    sat = is_sat(s)
    _init!(s) && (sat ? (iter = typemax(0)) : _optimizing!(s))
    add_time!(s, 2) # only used by MainSolver
    solve_for_loop!(s, stop, sat, iter, start_time)
    add_time!(s, 5) # only used by MainSolver
    remote_stop!(s)
    add_time!(s, 6) # only used by MainSolver
    post_process(s) # only used by MainSolver
end

"""
    solution(s)
Return the only/best known solution of a satisfaction/optimization model.
"""
solution(s) = has_solution(s) ? best_values(s) : _values(s)
