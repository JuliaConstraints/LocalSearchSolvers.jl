"""
    AbstractSolver
Abstract type to encapsulate the different solver types such as `Solver` or `_SubSolver`.
"""
abstract type AbstractSolver end

# Logger fields will be added to concrete solver types

"""
    SearchContext(model, state, logger)

Concrete view of the data used by the candidate loop. Solver shells deliberately keep broad
field types so models and states can be replaced during initialization; this immutable function
barrier recovers their runtime types once per neighborhood without restricting dynamic models.
"""
struct SearchContext{M, S, L}
    model::M
    state::S
    logger::L
end

_search_context(s) = SearchContext(s.model, s.state, s.logger)
_search_context(context::SearchContext) = context

# Dummy method to (not) add a TimeStamps to a solver
add_time!(::AbstractSolver, i) = nothing

function solver(ms, id, role; pool = pool(), strats = MetaStrategy(ms))
    mlid = make_id(meta_id(ms), id, Val(role))
    return solver(mlid, ms.model, ms.options, pool, ms.rc_report,
        ms.rc_sol, ms.rc_stop, strats, Val(role))
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
# Keep the model's concrete type inside the predicate instead of returning its
# parametric objective dictionary across the solver shell's abstract field.
@noinline _solver_is_sat(model::_Model) = is_sat(model)
is_sat(s::AbstractSolver) = _solver_is_sat(s.model)
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
@forward AbstractSolver.state _has_incremental
@forward AbstractSolver.state _invariant
@forward AbstractSolver.state _invariants
@forward AbstractSolver.state _last_improvement
@forward AbstractSolver.state _neighborhood_workspace
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

# Configure between runs. Existing local trajectories share this sink on their next run.
function set_option!(s::AbstractSolver, ::Val{:diagnostics}, value)
    set_option!(s.options, Val(:diagnostics), value)
    s.logger.diagnostics = value
    hasproperty(s, :subs) && foreach(sub -> set_option!(sub, Val(:diagnostics), value), s.subs)
    return value
end
set_option!(s::AbstractSolver, name::Symbol, value) = set_option!(s, Val(name), value)
set_option!(s::AbstractSolver, name::AbstractString, value) = set_option!(s, Symbol(name), value)

# Forwards from pool (of solutions)
@forward AbstractSolver.pool best_config
@forward AbstractSolver.pool best_value
@forward AbstractSolver.pool best_values
@forward AbstractSolver.pool has_solution
best_config(s::AbstractSolver) = best_config(_pool_snapshot(s))
best_value(s::AbstractSolver) = best_value(_pool_snapshot(s))
best_values(s::AbstractSolver) = best_values(_pool_snapshot(s))
has_solution(s::AbstractSolver) = has_solution(_pool_snapshot(s))

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
    for variable in keys(get_variables(s))
        _set!(s, variable, draw(s, variable))
    end
end

"""
    _compute_cost!(s, ind, c)

Compute the cost of constraint `c` with index `ind`.
"""
function _store_constraint_cost!(state::_State, ind, constraint, old_cost, new_cost)
    _cons_cost!(state, ind, new_cost)
    delta = new_cost - old_cost
    for variable in constraint.vars
        _var_cost!(state, variable, _var_cost(state, variable) + delta)
    end
    return new_cost
end

_compute_cost!(s, ind, c) = _compute_cost!(s.state, ind, c)

@inline _rebuild_owned_invariant!(invariant, input) = rebuild_invariant!(invariant, input)
const _IntegerSumOperator = Union{
    typeof(==), typeof(!=), typeof(<), typeof(<=), typeof(>), typeof(>=)}
function _rebuild_owned_invariant!(
        invariant::Constraints.SumInvariant{Vector{Int}, Int, F, Int},
        input::Vector{Int}) where {F <: _IntegerSumOperator}
    length(invariant.coefficients) == length(input) ||
        throw(DimensionMismatch("sum coefficients and values must have the same length"))
    # Machine integer arithmetic wraps, so regrouping this sum preserves its exact result.
    # Accumulate directly instead of allocating the product vector used by multi-array mapreduce.
    total = zero(Int)
    @inbounds for index in eachindex(input)
        total += invariant.coefficients[index] * input[index]
    end
    invariant.total = total
    return invariant_value(invariant)
end

function _compute_cost!(s::_State, ind, c)
    old_cost = _cons_cost(s, ind)
    values = _state_assignment(s)
    new_cost = if !_has_incremental(s)
        compute_cost(c, values, s.icn_computations, _constraint_input(s))
    else
        invariant = _invariant(s, ind)
        if !supports_incremental(invariant)
            input = constraint_input!(_constraint_input(s), c, values)
            value = apply(c, input, s.icn_computations)
            synchronize_invariant!(invariant, input, value)
        else
            input = constraint_input!(_constraint_input(s), c, values)
            _rebuild_owned_invariant!(invariant, input)
        end
    end
    return _store_constraint_cost!(s, ind, c, old_cost, new_cost)
end

_compute_committed_cost!(s, ind, c) = _compute_committed_cost!(s.state, ind, c)

function _compute_committed_cost!(s::_State, ind, c)
    old_cost = _cons_cost(s, ind)
    invariant = _invariant(s, ind)
    new_cost = if supports_incremental(invariant)
        invariant_value(invariant)
    else
        input = constraint_input!(
            _constraint_input(s), c, _state_assignment(s))
        value = apply(c, input, s.icn_computations)
        synchronize_invariant!(invariant, input, value)
    end
    return _store_constraint_cost!(s, ind, c, old_cost, new_cost)
end

"""
    _candidate_cost(s, move)

Evaluate the total violation after `move` without mutating the current assignment or the
stored constraint and variable costs. Only constraints incident to the moved variables are
evaluated.
"""
function _candidate_cost(context::SearchContext, move::AbstractMove)
    model = context.model
    state = context.state
    cost = get_error(state)
    constraints = get_constraints(model)
    values = _state_assignment(state)
    workspace = _neighborhood_workspace(state)
    affected = affected_constraints!(workspace, model, move, state.indexing)
    if !_has_incremental(state)
        for id in affected
            constraint = _state_value(constraints, id, state.indexing)
            cost += compute_cost(
                constraint,
                values,
                state.icn_computations,
                _constraint_input(state),
                move
            ) - _cons_cost(state, id)
        end
        return cost
    end
    for id in affected
        constraint = _state_value(constraints, id, state.indexing)
        changes = invariant_changes!(workspace, constraint, values, move)
        cost += candidate_value(_invariant(state, id), changes) - _cons_cost(state, id)
    end
    return cost
end

function _candidate_cost(model, state, logger, move::AbstractMove)
    return _candidate_cost(SearchContext(model, state, logger), move)::Float64
end

function _candidate_cost(s, move::AbstractMove)
    _candidate_cost(s.model, s.state, s.logger, move)::Float64
end

@testitem "Constraint inputs reuse solver-owned storage" default_imports = false begin
    import ConstraintDomains: domain
    import LocalSearchSolvers as LS
    import Test: @inferred, @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:4)), 1:4)
    function violation(values; X)
        @test values isa Vector{Int}
        return abs(sum(values) - 6)
    end
    LS.constraint!(model, violation, [1, 2, 3])
    solver = LS.solver(model;
        options = LS.Options(
            print_level = :silent,
            iteration = 1,
            process_threads_map = Dict(1 => 1)
        ))
    LS._init!(solver)

    context = LS._search_context(solver)
    input = solver.state.constraint_input
    @test length(input) == 3
    move = LS.AssignMove(1, 4)
    @test only(Base.return_types(LS._candidate_cost, Tuple{
        typeof(context), typeof(move)})) ===
          Float64
    @test only(Base.return_types(LS._move!, Tuple{typeof(context), Int, Int})) ===
          Tuple{Vector{Int}, Vector{Int}, Bool}
    candidate = @inferred LS._candidate_cost(context, move)
    @test solver.state.constraint_input === input
    @test length(input) == 3

    affected = LS._commit!(solver, move)
    LS._compute!(solver; cons_lst = affected)
    @test candidate == LS.get_error(solver)
    @test solver.state.constraint_input === input
end

@testitem "Dynamic models use the candidate context fallback" default_imports = false begin
    import ConstraintDomains: domain
    import LocalSearchSolvers as LS
    import Test: @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:3)), 1:3)
    LS.constraint!(model, (values; X) -> abs(sum(values) - 4), [1, 2, 3])
    solver = LS.solver(model;
        options = LS.Options(
            dynamic = true,
            print_level = :silent,
            iteration = 1,
            process_threads_map = Dict(1 => 1)
        ))
    LS._init!(solver)

    move = LS.AssignMove(1, 3)
    context = LS._search_context(solver)
    @test LS._candidate_cost(context, move) == LS._candidate_cost(solver, move)
end

@testitem "Constraint-owned invariants stay synchronized" default_imports = false begin
    import ConstraintDomains: domain
    import Constraints
    import Constraints: USUAL_CONSTRAINTS, bind_error, error_f
    import LocalSearchSolvers as LS
    import Test: @inferred, @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:4)), 1:4)
    LS.constraint!(model, error_f(USUAL_CONSTRAINTS[:all_different]), collect(1:4))
    sum_error = bind_error(
        error_f(USUAL_CONSTRAINTS[:sum]); op = ==, pair_vars = [1, 2, 3, 4], val = 20)
    LS.constraint!(model, sum_error, collect(1:4))
    LS.constraint!(model, (values; X) -> Float64(values[1] != values[2]), [1, 2])
    solver = LS.solver(model;
        options = LS.Options(
            print_level = :silent,
            iteration = 1,
            process_threads_map = Dict(1 => 1)
        ))
    LS._init!(solver)

    context = LS._search_context(solver)
    for move in (LS.AssignMove(1, 4), LS.SwapMove(1, 3))
        candidate = @inferred LS._candidate_cost(context, move)
        affected = LS._commit!(solver, move)
        LS._compute_committed!(solver; cons_lst = affected)
        @test candidate == LS.get_error(solver)
        @test all(
            id -> LS._cons_cost(solver, id) ==
                  Constraints.invariant_value(LS._invariant(solver, id)),
            affected)
    end

    LS._value!(solver, 2, 4)
    LS._compute!(solver)
    @test all(
        id -> LS._cons_cost(solver, id) ==
              Constraints.invariant_value(LS._invariant(solver, id)),
        keys(LS.get_constraints(solver)))
end

function _candidate_objective(context::SearchContext, move::AbstractMove, objective = 1)
    moved_values = MovedValues(getfield(_values(context.state), :values), move)
    return sense(context.model) *
           apply(get_objective(context.model, objective), moved_values)
end

function _candidate_objective(model, state, logger, move::AbstractMove, objective)
    return _candidate_objective(SearchContext(model, state, logger), move, objective)
end

function _candidate_objective(s, move::AbstractMove, objective = 1)
    _candidate_objective(s.model, s.state, s.logger, move, objective)
end

@inline function _candidate_rank(context::SearchContext, move::AbstractMove)
    cost = _candidate_cost(context, move)
    objective = _optimizing(context.state) && iszero(cost) ?
                _candidate_objective(context, move) : Inf
    @ls_diagnostic context :trace :candidate move=repr(move) violation=cost objective=objective
    return (cost, objective)
end

function _candidate_rank(model, state, logger, move::AbstractMove)
    _candidate_rank(SearchContext(model, state, logger), move)
end

_candidate_rank(s, move::AbstractMove) = _candidate_rank(s.model, s.state, s.logger, move)

function _commit!(s, move::AbstractMove)
    if s isa AbstractSolver && move isa MetaMove
        # Pass already-owned fields through the runtime model/state boundary;
        # boxing the entire immutable block move costs more than its metadata.
        return _commit_meta_parts!(s.model, s.state, move.meta_variable,
            move.variables, move.replacements, move.provenance)
    end
    return _commit!(s.model, s.state, move)
end

function _commit_meta_parts!(model, state, id, variables, replacements, provenance)
    return _commit!(model, state, MetaMove(id, variables, replacements, provenance))
end

function _commit!(model, state, move::AbstractMove)
    values = _state_assignment(state)
    workspace = _neighborhood_workspace(state)
    affected = affected_constraints!(workspace, model, move, state.indexing)
    if _has_incremental(state)
        for id in affected
            invariant = _invariant(state, id)
            supports_incremental(invariant) || continue
            constraint = _state_value(get_constraints(model), id, state.indexing)
            commit_changes!(invariant, invariant_changes!(workspace, constraint, values, move))
        end
    end
    empty!(workspace.moved_variables)
    empty!(workspace.moved_values)
    for variable in affected_variables(move)
        push!(workspace.moved_variables, variable)
        push!(workspace.moved_values, value_after(move, values, variable))
    end
    for index in eachindex(workspace.moved_variables)
        _value!(state, workspace.moved_variables[index], workspace.moved_values[index])
    end
    return affected
end

"""
    _compute_costs!(s; cons_lst::Indices{Int} = Indices{Int}())

Compute the cost of constraints `c` in `cons_lst`. If `cons_lst` is empty, compute the cost for all the constraints in `s`.
"""
function _compute_costs!(s; cons_lst = ())
    return _compute_costs!(s.model, s.state, cons_lst)
end

function _compute_costs!(model, state, cons_lst)
    if isempty(cons_lst)
        for (id, constraint) in pairs(get_constraints(model))
            _compute_cost!(state, id, constraint)
        end
    else
        constraints = get_constraints(model)
        for id in cons_lst
            _compute_cost!(state, id, _state_value(constraints, id, state.indexing))
        end
    end
    set_error!(state, sum(_cons_costs(state)))
end

function _compute_committed_costs!(s; cons_lst = ())
    return _compute_committed_costs!(s.model, s.state, cons_lst)
end

function _compute_committed_costs!(model, state, cons_lst)
    constraints = get_constraints(model)
    for id in cons_lst
        _compute_committed_cost!(
            state, id, _state_value(constraints, id, state.indexing))
    end
    set_error!(state, sum(_cons_costs(state)))
end

"""
    _compute_objective!(s, o::Objective)
    _compute_objective!(s, o = 1)

Compute the objective `o`'s value.
"""
function _compute_objective!(s, o::Objective)
    return _compute_objective!(s, s.model, s.state, o)
end

function _compute_objective!(s, model, state, o::Objective)
    val = sense(model) * apply(o, _values(state).values)
    set_value!(state, val)
    @ls_diagnostic s :debug :objective_evaluated proposed_score=val
    _consider_configuration!(s, state.configuration)
end
_compute_objective!(s, o = 1) = _compute_objective!(s, get_objective(s, o))

"""
    _compute!(s; o::Int = 1, cons_lst = Indices{Int}())

Compute the objective `o`'s value if `s` is satisfied and return the current `error`.

# Arguments:
- `s`: a solver
- `o`: targeted objective
- `cons_lst`: list of targeted constraints, if empty compute for the whole set
"""
function _finish_compute!(s, o)
    return _finish_compute!(s, s.model, s.state, o)
end

function _finish_compute!(s, model, state, o)
    if get_error(state) == 0.0
        if is_sat(model)
            _satisfying!(state)
            _consider_configuration!(s, state.configuration)
        else
            _optimizing!(state)
            _compute_objective!(s, model, state, get_objective(model, o))
        end
        return true
    end
    _satisfying!(state)
    return false
end

function _compute!(s; o::Int = 1, cons_lst = ())
    return _compute!(s, s.model, s.state, o, cons_lst)
end

function _compute!(s, model, state, o, cons_lst)
    _compute_costs!(model, state, cons_lst)
    return _finish_compute!(s, model, state, o)
end

function _compute_committed!(s; o::Int = 1, cons_lst = ())
    return _compute_committed!(s, s.model, s.state, o, cons_lst)
end

function _compute_committed!(s, model, state, o, cons_lst)
    _compute_committed_costs!(model, state, cons_lst)
    return _finish_compute!(s, model, state, o)
end

"""
    _neighbours(s, x, dim = 0)

DOCSTRING

# Arguments:
- `s`: DESCRIPTION
- `x`: DESCRIPTION
- `dim`: DESCRIPTION
"""
function _neighbours(context::SearchContext, x, dim = 0)
    model = context.model
    state = context.state
    workspace = _neighborhood_workspace(state)
    if dim == 0
        variable = _state_value(get_variables(model), x, state.indexing)
        is_continuous = typeof(variable.domain) <: ContinuousDomain
        if !is_continuous
            return get_domain(variable)
        end
        empty!(workspace.neighbor_values)
        for _ in 1:(length_vars(model) * length_cons(model))
            push!(workspace.neighbor_values, rand(variable))
        end
        return workspace.neighbor_values
    else
        generation = _next_variable_generation!(workspace, model)
        variables = get_variables(model)
        constraints = get_constraints(model)
        source = _state_value(variables, x, state.indexing)
        for constraint in _get_constraints(source)
            constrained = _state_value(constraints, constraint, state.indexing)
            for variable in _get_vars(constrained)
                variable == x && continue
                workspace.variable_marks[variable] == generation && continue
                target = _state_value(variables, variable, state.indexing)
                compatible = _value(state, x) ∈ target &&
                             _value(state, variable) ∈ source
                compatible || continue
                workspace.variable_marks[variable] = generation
                push!(workspace.neighbor_variables, variable)
            end
        end
        return workspace.neighbor_variables
    end
end

_neighbours(s, x, dim = 0) = _neighbours(_search_context(s), x, dim)

state!(s) = s.state = state(s)

iterations(::AbstractSolver) = 0
_iterations!(::AbstractSolver, ::Int) = nothing

function _init!(s, ::Val{:global})
    if !is_specialized(s) && get_option(s, "specialize")
        specialize!(s)
        set_option!(s, "specialize", true)
    end
    any(!isready(f) for f in values(s.remote_runs)) && error("previous remote solve is still active")
    empty!(s.remotes); empty!(s.remote_runs); empty!(s.remote_results)
    s.rc_stop = RemoteChannel(() -> Channel{Nothing}(1))
    s.status = :not_called
    _replace_pool!(s, pool())
end
function _init!(s, ::Val{:meta})
    empty!(s.subs)
    t = min(get_option(s, "threads"), Threads.nthreads())
    foreach(
        id -> push!(s.subs, solver(
            s, id - 1, :sub; strats = deepcopy(s.strategies))),
        2:t,
    )
    return nothing
end

function _init!(s, ::Val{:remote})
    for (w, threads) in sort!(collect(s.options.process_threads_map); by=first)
        (w == 1 || threads <= 0) && continue
        w in workers() || throw(ArgumentError("configured worker $w is not running"))
        s.remotes[w] = remotecall(_make_remote_solver, w, s.model, s.options,
            s.rc_report, s.rc_sol, s.rc_stop, deepcopy(s.strategies), w, threads)
    end
end

function _init!(s, ::Val{:local})
    get_option(s, "tabu_time") == 0 && set_option!(s, "tabu_time", length_vars(s) ÷ 2) # 10?
    get_option(s, "tabu_local") == 0 &&
        set_option!(s, "tabu_local", get_option(s, "tabu_time") ÷ 2)
    get_option(s, "tabu_delta") == 0 && set_option!(
        s, "tabu_delta", get_option(s, "tabu_time") - get_option(s, "tabu_local")) # 20-30
    state!(s)
    pool!(s)
    _initialize_proposals!(s, s.strategies)

    # Initialize progress tracker if it exists
    if !isnothing(s.progress_tracker)
        reset_progress!(s.progress_tracker)

        # Log initialization
        if s.logger.config.log_mode == :full
            log_info(s.logger,
                "Initializing solver with $(length_vars(s)) variables and $(length_cons(s)) constraints")

            # Log limits if set
            if get_option(s, "iteration")[1]
                log_info(
                    s.logger, "Iteration limit: $(get_option(s, "iteration")[2])")
            end

            if get_option(s, "time_limit")[1]
                log_info(s.logger,
                    "Time limit: $(get_option(s, "time_limit")[2]) seconds")
            end
        end
    end

    return has_solution(s)
end

_init!(s, role::Symbol) = _init!(s, Val(role))

function _restart_values!(s, strategy::RestartStrategy)
    return _restart_values!(s, s.model, s.state, strategy)
end

function _restart_values!(s, model, state, strategy::RestartStrategy)
    source = restart_source(strategy)
    if source === :best && !is_empty(s.pool)
        for (variable, value) in pairs(best_values(s.pool))
            _set!(state, variable, value)
        end
    end
    variables = _neighborhood_workspace(state).restart_variables
    empty!(variables)
    # Refill in model order before shuffling: reusing last shuffle would change RNG traces.
    append!(variables, keys(get_variables(model)))
    count = clamp(ceil(Int, restart_fraction(strategy) * length(variables)),
        0, length(variables))
    count == 0 && return nothing
    shuffle!(variables)
    for variable in @view variables[1:count]
        _set!(state, variable, draw(model, variable))
    end
    return nothing
end

"""Restart a solver according to its trigger-independent restart policy."""
function _restart!(s, k = 10)
    return _restart!(s, s.model, s.state, s.logger, s.strategies, k)
end

function _restart!(s, model, state, logger, strategies, k)
    @ls_diagnostic s :summary :restart_begin
    @ls_debug logger "\n============== RESTART!!!!================\n"
    _restart_values!(s, model, state, strategies.restart)
    empty_tabu!(strategies)
    _reset_last_improvement!(state)
    δ = ((k - 1) * get_option(s, Val(:tabu_delta))) + get_option(s, Val(:tabu_time)) / k
    set_option!(s, Val(:tabu_delta), δ)
    _compute_costs!(model, state, ())
    result = (_finish_compute!(s, model, state, 1) && !is_sat(model)) ?
        _optimizing!(state) : _satisfying!(state)
    @ls_diagnostic s :summary :restart_end
    return result
end

function _update_unsatisfied_incumbent!(s)
    is_solution(s.state.configuration) && return false
    return _consider_configuration!(s, s.state.configuration)
end

"""
    _check_restart(s)

Check if a restart of `s` is necessary. If `s` has subsolvers, this check is independent for all of them.
"""
_check_restart(s) = _check_restart(s.model, s.state, s.strategies)
function _check_restart(model, state, strategies)
    a = _last_improvement(state) > length_vars(model)
    # Evaluate the trigger even when stagnation is reached: it may update state or RNG.
    b = check_restart!(strategies; tabu_length = length_tabu(strategies))
    return a || b
end

@testitem "Restart policies restore incumbents and reset stagnation" default_imports=false begin
    import ConstraintDomains: domain
    import Constraints
    import LocalSearchSolvers as LS
    import Test: @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:4)), 1:4)
    LS.constraint!(model, Constraints.make_error(:all_different), 1:4)
    trigger = LS.restart(nothing, Val(:random); rp = 1.0)
    strategy = LS.MetaStrategy(model;
        restart = LS.restart_policy(trigger; reset_fraction = 0.0, source = :best))
    solver = LS.solver(model;
        strategies = strategy,
        options = LS.Options(
            print_level = :silent, iteration = 1, process_threads_map = Dict(1 => 1)))
    LS._init!(solver)
    incumbent = collect(pairs(LS.best_values(solver.pool)))
    foreach(variable -> LS._value!(solver, variable, 1), 1:4)
    LS._compute!(solver)
    LS._inc_last_improvement!(solver)
    LS._restart!(solver)
    @test collect(pairs(LS.get_values(solver))) == incumbent
    @test LS._last_improvement(solver) == 0
end

"""
    _select_worse(s::S) where S <: Union{_State, AbstractSolver}
Within the non-tabu variables, select the one with the worse error .
"""
function _select_worse(s)
    return select_target(s.strategies.variable_selection, s)
end

"""
    _move!(s, x::Int, dim::Int = 0)

Perform an improving move in `x` neighbourhood if possible.

# Arguments:
- `s`: a solver of type S <: AbstractSolver
- `x`: selected variable id
- `dim`: describe the dimension of the considered neighbourhood
"""
function _assignment_move!(
        context::SearchContext,
        x::Int,
        generator::AbstractNeighborhoodGenerator,
        acceptance::AbstractAcceptanceStrategy,
        depth::Int = 0
)
    state = context.state
    workspace = _neighborhood_workspace(state)
    old_v = _value(state, x)
    best_values = workspace.best_values
    best_swap = workspace.best_swaps
    empty!(best_values)
    push!(best_values, old_v)
    empty!(best_swap)
    push!(best_swap, x)
    tabu = true # unless proved otherwise, this variable is now tabu
    best_rank = (get_error(state), _optimizing(state) ? get_value(state) : Inf)
    request = NeighborhoodRequest(context, x, depth, nothing)
    moves = generate_moves(generator, request, Val(:assignment))
    for move in moves
        value = move.value
        @ls_debug context.logger "Compute costs: selected var(s) x_$x = $value"
        rank = _candidate_rank(context, move)
        relation = candidate_relation(acceptance, rank, best_rank)
        if relation > 0
            @ls_debug context.logger "candidate rank = $rank < $best_rank"
            tabu = false
            best_rank = rank
            empty!(best_values)
            push!(best_values, value)
        elseif iszero(relation)
            @ls_debug context.logger "candidate rank = best rank = $rank"
            push!(best_values, value)
        end

        if iszero(rank[1]) && is_sat(context.model)
            return best_values, best_swap, tabu
        end
    end
    return best_values, best_swap, tabu
end

function _swap_move!(
        context::SearchContext,
        x::Int,
        generator::AbstractNeighborhoodGenerator,
        acceptance::AbstractAcceptanceStrategy,
        depth::Int
)
    state = context.state
    workspace = _neighborhood_workspace(state)
    old_v = _value(state, x)
    best_values = workspace.best_values
    best_swap = workspace.best_swaps
    isempty(best_values) && push!(best_values, old_v)
    empty!(best_swap)
    push!(best_swap, x)
    tabu = true
    best_rank = (get_error(state), _optimizing(state) ? get_value(state) : Inf)
    request = NeighborhoodRequest(context, x, depth, nothing)
    moves = generate_moves(generator, request, Val(:swap))
    for move in moves
        variable = move.second
        @ls_debug context.logger "Compute costs: selected var(s) x_$x ⇆ x_$variable"
        rank = _candidate_rank(context, move)
        relation = candidate_relation(acceptance, rank, best_rank)
        if relation > 0
            @ls_debug context.logger "candidate rank = $rank < $best_rank"
            tabu = false
            best_rank = rank
            empty!(best_swap)
            push!(best_swap, variable)
        elseif iszero(relation)
            @ls_debug context.logger "candidate rank = best rank = $rank"
            push!(best_swap, variable)
        end

        if iszero(rank[1]) && is_sat(context.model)
            return best_values, best_swap, tabu
        end
    end
    return best_values, best_swap, tabu
end

function _move!(
        context::SearchContext,
        x::Int,
        generator::AbstractNeighborhoodGenerator,
        acceptance::AbstractAcceptanceStrategy,
        dim::Int = 0
)
    dim == 0 && return _assignment_move!(context, x, generator, acceptance)
    dim > 0 && return _swap_move!(context, x, generator, acceptance, dim)
    throw(ArgumentError("neighborhood depth must be non-negative"))
end

function _move!(
        context::SearchContext,
        x::Int,
        generator::NativeDecisionNeighborhood,
        acceptance::AbstractAcceptanceStrategy,
        depth::Int = 0
)
    return _native_decision_move!(context, x, acceptance, depth)
end

function _move!(context::SearchContext, x::Int,
        generator::AbstractNeighborhoodGenerator, dim::Int = 0)
    return _move!(context, x, generator, BestImprovingAcceptance(), dim)
end

function _move!(context::SearchContext, x::Int, dim::Int = 0)
    _move!(context, x, AssignSwapNeighborhood(), dim)
end

function _move!(model, state, logger, x::Int, dim::Int)
    _move!(SearchContext(model, state, logger), x, dim)
end

_move!(s, x::Int, dim::Int = 0) = _move!(s.model, s.state, s.logger, x, dim)

function _move!(s, x::Int, generator::AbstractNeighborhoodGenerator, dim::Int = 0)
    _move!(_search_context(s), x, generator, dim)
end

"""
    _step!(s)

Iterate a step of the solver run.
"""
_step!(s) = _step!(s, s.model, s.state, s.logger, s.strategies)

function _step!(s, model, state, logger)
    return _step!(s, model, state, logger, s.strategies)
end

# Model, state, logger and strategy may be replaced between steps. Specialize
# this kernel on their current concrete types without freezing the solver shell.
function _step!(s, model, state, logger, strategy, cost_update::AbstractCostUpdate=RuntimeCostUpdate())
    @ls_diagnostic s :debug :step_begin
    # select worst variables
    x = _select_target(strategy.variable_selection, s, state, strategy)
    @ls_debug logger "Selected x = $x"

    # Local move (change the value of the selected variable)
    context = SearchContext(model, state, logger)
    best_values = _neighborhood_workspace(state).best_values
    best_swap = _neighborhood_workspace(state).best_swaps
    tabu = true
    for depth in strategy.depths
        best_values, best_swap, tabu = _move!(
            context, x, strategy.neighborhood, strategy.acceptance, depth)
        tabu || break
    end

    # decay tabu list
    decay_tabu!(strategy)

    # update tabu list with either worst or selected variable
    insert_tabu!(strategy, x, tabu ? :tabu : :pick)
    @ls_debug logger "Tabu list: $(tabu_list(s))"

    # Inc last improvement if tabu
    tabu ? _inc_last_improvement!(state) : _reset_last_improvement!(state)

    # Select the best move (value or swap)
    move = if x ∈ best_swap
        selected = AssignMove(x, rand(best_values))
        @ls_debug logger "best_values: $best_values"
        selected
    else
        selected = SwapMove(x, rand(best_swap))
        @ls_debug logger "best_swap : $best_swap"
        selected
    end
    affected = _commit!(model, state, move)
    @ls_debug logger "After move: values=$(length(_values(s)) > 0 ? _values(s) : nothing)"

    # Compute costs and possibly evaluate objective functions
    # return true if a solution for sat is found
    # if _compute!(s)
    #     !is_sat(s) ? _optimizing!(s) : return true
    # end
    _update_move_costs!(cost_update,model,state,affected)
    computed = _finish_compute!(s, model, state, 1)
    computed || _update_unsatisfied_incumbent!(s)
    if computed
        if !is_sat(model)
            # _finish_compute! already evaluated and admitted this configuration.
            @ls_debug logger "Optimization candidate evaluated"
        else
            @ls_debug logger "Solution found, pool has_solution=$(has_solution(s))"
            @ls_diagnostic s :summary :satisfaction_found values=collect(get_values(best_config(s.pool)))
            @ls_diagnostic s :audit :consistency truth=_diagnostic_truth(s)
            return true
        end
    end

    # Restart if necessary
    _check_restart(model, state, strategy) && _restart!(s, model, state, logger, strategy, 10)
    @ls_diagnostic s :debug :step_end
    @ls_diagnostic s :audit :consistency truth=_diagnostic_truth(s)

    return false # no satisfying configuration or optimizing
end

@testitem "Candidate costs are non-mutating deltas" default_imports = false begin
    import ConstraintDomains: domain
    import Constraints: USUAL_CONSTRAINTS, error_f
    import LocalSearchSolvers as LS
    import Test: @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:4)), 1:4)
    all_different = (x; X) -> error_f(USUAL_CONSTRAINTS[:all_different])(x)
    sum_to_ten = (x; X) -> error_f(USUAL_CONSTRAINTS[:sum])(x; op = ==, val = 10)
    LS.constraint!(model, all_different, collect(1:4))
    LS.constraint!(model, sum_to_ten, collect(1:4))

    solver = LS.solver(model;
        options = LS.Options(
            print_level = :silent, iteration = 1,
            process_threads_map = Dict(1 => 1)))
    LS._init!(solver)

    original_values = collect(pairs(LS.get_values(solver)))
    original_constraint_costs = collect(pairs(LS._cons_costs(solver)))
    original_variable_costs = collect(pairs(LS._vars_costs(solver)))

    for move in (LS.AssignMove(1, 4), LS.SwapMove(1, 2))
        reverse = move isa LS.AssignMove ?
                  LS.AssignMove(move.variable, LS.get_value(solver, move.variable)) : move
        candidate = LS._candidate_cost(solver, move)
        @test collect(pairs(LS.get_values(solver))) == original_values
        @test collect(pairs(LS._cons_costs(solver))) == original_constraint_costs
        @test collect(pairs(LS._vars_costs(solver))) == original_variable_costs

        affected = LS._commit!(solver, move)
        LS._compute!(solver; cons_lst = affected)
        @test candidate == LS.get_error(solver)

        LS._commit!(solver, reverse)
        LS._compute!(solver; cons_lst = affected)
        @test collect(pairs(LS.get_values(solver))) == original_values
        @test collect(pairs(LS._cons_costs(solver))) == original_constraint_costs
        @test collect(pairs(LS._vars_costs(solver))) == original_variable_costs
    end
end

@testitem "Candidate objectives use moved values" default_imports = false begin
    import ConstraintDomains: domain
    import LocalSearchSolvers as LS
    import Test: @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:4)), 1:2)
    LS.objective!(model, sum)
    solver = LS.solver(model;
        options = LS.Options(
            print_level = :silent, iteration = 1,
            process_threads_map = Dict(1 => 1)))
    LS._init!(solver)
    solver.state.optimizing = true

    move = LS.AssignMove(1, 4)
    original = LS.get_value(solver, 1)
    expected = sum(LS.value_after(move, LS.get_values(solver), i) for i in 1:2)
    @test LS._candidate_objective(solver, move) == expected
    @test LS.get_value(solver, 1) == original
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
# Keep the tracker and state concrete while forming the keyword arguments. This
# also preserves tracking when display mode is NONE: only the call overhead changes.
function _update_iteration_progress!(tracker, state, iter)
    update_progress!(tracker;
        iteration = iter,
        error = get_error(state),
        objective = _optimizing(state) ? get_value(state) : nothing)
    return nothing
end

# Updating numerical fields does not need a wall clock. Public update_progress!
# still returns the time and timestamps first solutions; custom trackers retain
# their public callback. ProgressMeter needs its callback when a meter is active.
@inline function _iteration_progress_fields!(tracker, state, iter)
    tracker.current_iteration = iter
    error = get_error(state)
    tracker.initial_error == Inf && (tracker.initial_error = error)
    tracker.current_error = error
    if _optimizing(state)
        objective = get_value(state)
        if isnothing(tracker.best_objective) || objective < tracker.best_objective
            tracker.best_objective = objective
        end
    end
    return nothing
end
_update_iteration_progress!(tracker::ProgressTracker, state, iter) =
    _iteration_progress_fields!(tracker, state, iter)
function _update_iteration_progress!(tracker::ProgressMeterTracker, state, iter)
    tracker.enabled || return nothing
    if isnothing(tracker.progress)
        _iteration_progress_fields!(tracker, state, iter)
    else
        update_progress!(tracker; iteration=iter, error=get_error(state),
            objective=_optimizing(state) ? get_value(state) : nothing)
    end
    return nothing
end

function solve_while_loop!(s, stop, sat, iter, st)
    builder = get_option(s, Val(:execution_builder))
    isnothing(builder) && return _dispatch_search_loop!(s, stop, sat, iter, st, s.strategies)
    # One preparation boundary per trajectory. The historical hot loop is untouched.
    context = builder(s)
    return _run_prepared_loop!(context,s,stop,sat,iter,st)
end
_run_prepared_loop!(context,s,stop,sat,iter,st)=_solve_while_loop!(s,stop,sat,iter,st,context)
_dispatch_search_loop!(s, stop, sat, iter, st, strategy) =
    _default_while_loop!(s, stop, sat, iter, st)
@inline _context_step!(::Nothing, s) = _step!(s)
@inline _context_progress!(::Nothing, s, iter) = _update_iteration_progress!(s.progress_tracker, s.state, iter)

# Preserve the direct-call compatibility loop: routing its hot calls through the
# explicit-context loop regressed permutation timings. Keep stop/pool/progress
# semantics aligned with the explicit loop below; the strategy dispatch is once
# per solve. See ConstraintLearningBenchmarks perf/paired_extended_regression.jl.
function _default_while_loop!(s, stop, sat, iter, st)
    # Track last progress update time for remote solvers
    last_progress_update_time = time()
    update_interval = get_option(s, "progress_update_interval", 0.1) * 10  # Less frequent than display updates

    while stop_while_loop(s, stop, iter, st)
        iter += 1
        _iterations!(s, iter)
        @ls_diagnostic s :debug :iteration iteration_count=iter

        # Update progress with iteration
        if !isnothing(s.progress_tracker)
            _update_iteration_progress!(s.progress_tracker, s.state, iter)
            display_progress!(s.progress_tracker, s.logger)

            # Log solver state if needed
            if s.logger.config.log_mode == :full
                log_solver_state(
                    s.logger,
                    s.progress_tracker.solver_id,
                    iter,
                    get_error(s),
                    is_sat(s),
                    _optimizing(s) ? get_value(s) : nothing
                )
            end

            # For LeadSolver, periodically send progress updates to main solver
            if s isa LeadSolver && time() - last_progress_update_time >= update_interval
                send_progress_update(s, 1)  # Send to worker 1 (main)
                last_progress_update_time = time()
            end

            # For MainSolver, periodically update progress from remote solvers
            if s isa MainSolver &&
               get_option(s, "show_remote_progress", true) &&
               time() - last_progress_update_time >= update_interval
                update_remote_progress!(s)
                last_progress_update_time = time()
            end
        end

        @ls_debug s.logger "\n\tLoop $(iter) ($(_optimizing(s) ? "optimization" : "satisfaction"))"

        # If step finds a solution, update progress and break if in satisfaction mode
        if _step!(s) && sat
            # Update progress if solution found
            if !isnothing(s.progress_tracker)
                update_progress!(s.progress_tracker, has_valid_solution = true)
                display_progress!(s.progress_tracker, s.logger)

                if s.logger.config.log_mode == :full
                    log_info(s.logger, "Solution found at iteration $(iter)")
                end

                # For LeadSolver, send immediate progress update when solution found
                if s isa LeadSolver
                    send_progress_update(s, 1)  # Send to worker 1 (main)
                end
            end
            _solution_limit_reached(s) && break
        end

        @ls_debug s.logger "vals: $(length(_values(s)) > 0 ? _values(s) : nothing)"

        # Check sub-solvers
        best_sub = _check_subs(s)
        if best_sub > 0
            bs = s.subs[best_sub]
            incoming = _pool_snapshot(bs)
            @ls_diagnostic s :summary :subsolver_selected subsolver=best_sub incoming=_diagnostic_pool(incoming) incoming_values=collect(best_values(incoming))
            update_pool!(s, incoming)

            # Update progress if solution found from sub-solver
            if !isnothing(s.progress_tracker) && sat
                update_progress!(s.progress_tracker, has_valid_solution = true)
                display_progress!(s.progress_tracker, s.logger)

                if s.logger.config.log_mode == :full
                    log_info(s.logger, "Solution found from sub-solver $(best_sub)")
                end
            end

            sat && _solution_limit_reached(s) && break
        end
    end

    # Finalize progress display
    if !isnothing(s.progress_tracker)
        finalize_progress!(s.progress_tracker, s.logger)

        if s.logger.config.log_mode == :full
            if has_solution(s)
                log_info(s.logger, "Solving completed with valid solution")
                if _optimizing(s)
                    log_info(s.logger, "Best objective value: $(best_value(s))")
                end
            else
                log_info(s.logger, "Solving completed without valid solution")
                log_info(s.logger, "Final error: $(get_error(s))")
            end
        end
    end
end


function _solve_while_loop!(s, stop, sat, iter, st, context)
    # Track last progress update time for remote solvers
    last_progress_update_time = time()
    update_interval = get_option(s, "progress_update_interval", 0.1) * 10  # Less frequent than display updates

    while stop_while_loop(s, stop, iter, st)
        iter += 1
        _iterations!(s, iter)
        @ls_diagnostic s :debug :iteration iteration_count=iter

        # Update progress with iteration
        if !isnothing(s.progress_tracker)
            _context_progress!(context, s, iter)
            display_progress!(s.progress_tracker, s.logger)

            # Log solver state if needed
            if s.logger.config.log_mode == :full
                log_solver_state(
                    s.logger,
                    s.progress_tracker.solver_id,
                    iter,
                    get_error(s),
                    is_sat(s),
                    _optimizing(s) ? get_value(s) : nothing
                )
            end

            # For LeadSolver, periodically send progress updates to main solver
            if s isa LeadSolver && time() - last_progress_update_time >= update_interval
                send_progress_update(s, 1)  # Send to worker 1 (main)
                last_progress_update_time = time()
            end

            # For MainSolver, periodically update progress from remote solvers
            if s isa MainSolver &&
               get_option(s, "show_remote_progress", true) &&
               time() - last_progress_update_time >= update_interval
                update_remote_progress!(s)
                last_progress_update_time = time()
            end
        end

        @ls_debug s.logger "\n\tLoop $(iter) ($(_optimizing(s) ? "optimization" : "satisfaction"))"

        # If step finds a solution, update progress and break if in satisfaction mode
        if _context_step!(context, s) && sat
            # Update progress if solution found
            if !isnothing(s.progress_tracker)
                update_progress!(s.progress_tracker, has_valid_solution = true)
                display_progress!(s.progress_tracker, s.logger)

                if s.logger.config.log_mode == :full
                    log_info(s.logger, "Solution found at iteration $(iter)")
                end

                # For LeadSolver, send immediate progress update when solution found
                if s isa LeadSolver
                    send_progress_update(s, 1)  # Send to worker 1 (main)
                end
            end
            _solution_limit_reached(s) && break
        end

        @ls_debug s.logger "vals: $(length(_values(s)) > 0 ? _values(s) : nothing)"

        # Check sub-solvers
        best_sub = _check_subs(s)
        if best_sub > 0
            bs = s.subs[best_sub]
            incoming = _pool_snapshot(bs)
            @ls_diagnostic s :summary :subsolver_selected subsolver=best_sub incoming=_diagnostic_pool(incoming) incoming_values=collect(best_values(incoming))
            update_pool!(s, incoming)

            # Update progress if solution found from sub-solver
            if !isnothing(s.progress_tracker) && sat
                update_progress!(s.progress_tracker, has_valid_solution = true)
                display_progress!(s.progress_tracker, s.logger)

                if s.logger.config.log_mode == :full
                    log_info(s.logger, "Solution found from sub-solver $(best_sub)")
                end
            end

            sat && _solution_limit_reached(s) && break
        end
    end

    # Finalize progress display
    if !isnothing(s.progress_tracker)
        finalize_progress!(s.progress_tracker, s.logger)

        if s.logger.config.log_mode == :full
            if has_solution(s)
                log_info(s.logger, "Solving completed with valid solution")
                if _optimizing(s)
                    log_info(s.logger, "Best objective value: $(best_value(s))")
                end
            else
                log_info(s.logger, "Solving completed without valid solution")
                log_info(s.logger, "Final error: $(get_error(s))")
            end
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
    for candidate in pool.configurations
        _consider_configuration!(s, candidate)
    end
    return nothing
end

"""
    remote_stop!!(solver)
Fetch the pool of solutions from `LeadSolvers` and merge it into the `MainSolver`.
"""
remote_stop!(::AbstractSolver) = nothing

"""
    post_process(s::MainSolver)
Launch a series of tasks to round-up a solving run, for instance, export a run's info.
"""
post_process(::AbstractSolver) = nothing

_validate_execution_builder(builder,s) = nothing
_strategy_run_records(s)=_strategy_run_records(get_option(s,Val(:execution_builder)),s)
_strategy_run_records(builder,s)=nothing

_solve_lease(builder,s)=nothing
_solve_release(::Nothing)=nothing
function solve!(s, stop = Atomic{Bool}(false))
    lease=_solve_lease(get_option(s,Val(:execution_builder)),s)
    try
        _solve_owned!(s,stop)
    finally
        _solve_release(lease)
    end
end
function _solve_owned!(s, stop)
    _validate_execution_builder(get_option(s,Val(:execution_builder)),s)
    @ls_diagnostic s :summary :solve_start
    start_time = time()

    # Log start of solving
    if !isnothing(s.progress_tracker) && s.logger.config.log_mode == :full
        log_info(s.logger, "Starting solver")
    end

    add_time!(s, 1) # only used by MainSolver
    iter = 0 # only used by MainSolver
    _iterations!(s, iter)
    sat = is_sat(s)

    try
    # Initialize and check if already solved
    if _init!(s)
        if sat && _solution_limit_reached(s)
            # Log already solved
            if !isnothing(s.progress_tracker) && s.logger.config.log_mode == :full
                log_info(s.logger, "Problem already satisfied during initialization")
            end
        elseif !sat
            _optimizing!(s)

            # Log switching to optimization
            if !isnothing(s.progress_tracker) && s.logger.config.log_mode == :full
                log_info(s.logger, "Switching to optimization mode")
            end
        end
    end

    add_time!(s, 2) # only used by MainSolver
    @ls_diagnostic s :summary :initialized

    # Main solving loop
    solve_for_loop!(s, stop, sat, iter, start_time)
    catch
        atomic_or!(stop, true)
        if s isa MainSolver
            _signal_remote_stop!(s)
            try
                remote_stop!(s)
            catch cleanup_error
                @error "Remote cleanup also failed after solver exception" exception=cleanup_error
            end
        end
        rethrow()
    end

    add_time!(s, 5) # only used by MainSolver
    remote_stop!(s)
    add_time!(s, 6) # only used by MainSolver

    # Log end of solving
    if !isnothing(s.progress_tracker) && s.logger.config.log_mode == :full
        elapsed = time() - start_time
        log_info(s.logger, "Solver finished in $(@sprintf("%.3f", elapsed)) seconds")
    end

    result = post_process(s) # only used by MainSolver
    @ls_diagnostic s :summary :solve_end termination=hasproperty(s,:status) ? s.status : :worker_finished
    @ls_diagnostic s :audit :consistency truth=_diagnostic_truth(s)
    return result
end

"""
    solution(s)
Return the only/best known solution of a satisfaction/optimization model.
"""
function solution(s)
    snapshot = _pool_snapshot(s)
    is_empty(snapshot) ? _values(s) : best_values(snapshot)
end
