# Explicit proposal execution. The compatibility _step! remains unchanged.
# No seventh policy: the six MetaStrategy components retain their responsibilities.
function _dispatch_search_loop!(s, stop, sat, iter, st,
        strategy::MetaStrategy{VS,NG,DS,AS}) where {VS,NG,DS,AS<:ExplicitMoveAcceptance}
    # Explicit strategies require dynamic=false: hold the
    # execution objects for this solve, and specialize the shared control loop.
    context = (s.model, s.state, s.logger, strategy, s.progress_tracker)
    return _solve_while_loop!(s, stop, sat, iter, st, context)
end
@inline _context_step!(context::Tuple, s) = _step!(s, context[1], context[2], context[3], context[4])
@inline _context_progress!(context::Tuple, s, iter) = _update_iteration_progress!(context[5], context[2], iter)

function _initialize_proposals!(s, strategy)
    (strategy.variable_selection isa RemainingWorstSelector ||
     strategy.tabu isa EventTabu || strategy.restart isa ExhaustionRestart) &&
        throw(ArgumentError("event-based strategies require ExplicitMoveAcceptance"))
    return nothing
end

function _initialize_proposals!(s, strategy::MetaStrategy{VS,NG,DS,AS}) where {VS,NG,DS,AS<:ExplicitMoveAcceptance}
    get_option(s, Val(:dynamic)) && throw(ArgumentError("explicit proposal strategies currently require dynamic=false"))
    length_vars(s.model) > 0 || throw(ArgumentError("explicit proposals require variables"))
    length_objs(s.model) <= 1 || throw(ArgumentError("explicit proposals currently support one objective"))
    strategy.neighborhood isa NativeDecisionNeighborhood && throw(ArgumentError("native compound moves are not yet supported by explicit proposals"))
    if strategy.neighborhood isa AssignmentNeighborhood
        all(iszero, strategy.depths) || throw(ArgumentError("AssignmentNeighborhood requires depth zero"))
    end
    for variable in get_variables(s.model)
        variable.domain isa ContinuousDomain && throw(ArgumentError("explicit proposals require finite domains"))
        all(x -> x isa Real && isfinite(x), get_domain(variable)) ||
            throw(ArgumentError("explicit proposals currently require finite scalar real domains"))
    end
    selector = strategy.variable_selection
    if selector isa RemainingWorstSelector
        empty!(selector.pending); sizehint!(selector.pending, length_vars(s.model)); selector.refresh = true
    end
    empty_tabu!(strategy)
    strategy.restart isa ExhaustionRestart && (strategy.restart.resets = 0)
    _reset_proposal_acceptance!(strategy.acceptance, s.model, s.state)
    return nothing
end

function _reset_proposal_acceptance!(a::GreedyPlateauAcceptance, model, state)
    a.current_objective = !is_sat(model) && iszero(get_error(state)) ? get_value(state) : Inf
end
_current_proposal_rank(a::GreedyPlateauAcceptance, model, state) = (get_error(state), a.current_objective)
function _accepted_objective!(a::GreedyPlateauAcceptance, model, state)
    a.current_objective = is_sat(model) ? Inf : iszero(get_error(state)) ? get_value(state) :
        _guide_infeasible(a) ? sense(model) * apply(get_objective(model, 1), getfield(_values(state), :values)) : Inf
end

@inline function _proposal_rank(a::GreedyPlateauAcceptance, context, move)
    cost = _candidate_cost(context, move)
    objective = !is_sat(context.model) && (iszero(cost) || _guide_infeasible(a)) ?
        _candidate_objective(context, move) : Inf
    @ls_diagnostic context :trace :candidate move=repr(move) violation=cost objective=objective
    return (cost, objective)
end
_remember_proposal!(workspace, move::AssignMove) = push!(workspace.best_values, move.value)
_remember_proposal!(workspace, move::SwapMove) = push!(workspace.best_swaps, move.second)
_remember_proposal!(workspace, move) = throw(ArgumentError("explicit proposals currently support AssignMove and SwapMove"))

# The depth-dependent generator may return assignment or swap iterators. Keep
# that union outside the candidate loop: otherwise iterate() results and moves
# are boxed on every candidate even when both iterator types are concrete.
@noinline function _scan_proposals!(context, acceptance, workspace, moves, best_rank)
    for move in moves
        rank = _proposal_rank(acceptance, context, move)
        if rank < best_rank
            best_rank = rank
            empty!(workspace.best_values); empty!(workspace.best_swaps)
            _remember_proposal!(workspace, move)
        elseif rank == best_rank
            _remember_proposal!(workspace, move)
        end
    end
    return best_rank
end

function _best_proposal!(context, x, strategy)
    workspace = _neighborhood_workspace(context.state)
    empty!(workspace.best_values); empty!(workspace.best_swaps)
    best_rank = (Inf, Inf)
    for depth in strategy.depths
        request = NeighborhoodRequest(context, x, depth, nothing)
        moves = generate_moves(strategy.neighborhood, request)
        best_rank = _scan_proposals!(context, strategy.acceptance, workspace, moves, best_rank)
    end
    count = length(workspace.best_values) + length(workspace.best_swaps)
    count == 0 && return nothing, best_rank
    chosen = rand(1:count)
    # Return concrete tuple variants, not a tuple with a union-typed move field.
    # The latter boxes each proposal when crossing the function boundary.
    if chosen <= length(workspace.best_values)
        return AssignMove(x, workspace.best_values[chosen]), best_rank
    else
        return SwapMove(x, workspace.best_swaps[chosen - length(workspace.best_values)]), best_rank
    end
end

_proposal_reset_needed(rs, model, state, strategy, x) =
    x === nothing || _check_restart(model, state, strategy)
_proposal_reset_needed(rs::ExhaustionRestart, model, state, strategy, x) =
    x === nothing || length_tabu(strategy) >= rs.tabu_threshold

function _reset_proposal_state!(s, model, state, logger, strategy)
    strategy.restart isa ExhaustionRestart && (strategy.restart.resets += 1)
    _restart_values!(s, model, state, strategy.restart)
    empty_tabu!(strategy)
    _reset_last_improvement!(state)
    _selection_result!(strategy.variable_selection, :reset)
    _compute_costs!(model, state, ())
    solved = _finish_compute!(s, model, state, 1)
    solved || _update_unsatisfied_incumbent!(s)
    _reset_proposal_acceptance!(strategy.acceptance, model, state)
    @ls_diagnostic s :debug :proposal_reset
    @ls_diagnostic s :audit :consistency truth=_diagnostic_truth(s)
    return solved && is_sat(model)
end

function _proposal_event!(strategy, x, event)
    _advance_proposal_tabu!(strategy.tabu, event)
    if event === :accepted
        insert_tabu!(strategy.tabu, x, :pick)
    elseif event === :plateau_rejected || _remaining_empty(strategy.variable_selection)
        insert_tabu!(strategy.tabu, x, :tabu)
    end
    _selection_result!(strategy.variable_selection, event)
    # Proposal-clock expiration may re-enable a variable while costs are unchanged.
    if strategy.variable_selection isa RemainingWorstSelector &&
       !(strategy.tabu isa EventTabu{:accepted} || strategy.tabu isa NoTabu)
        strategy.variable_selection.refresh = true
    end
    return nothing
end

@inline _step!(s,model,state,logger,strategy::MetaStrategy{VS,NG,DS,AS},::AbstractCostUpdate) where {VS,NG,DS,AS<:ExplicitMoveAcceptance} =
    _step!(s,model,state,logger,strategy)
function _step!(s, model, state, logger, strategy::MetaStrategy{VS,NG,DS,AS}) where {VS,NG,DS,AS<:ExplicitMoveAcceptance}
    @ls_diagnostic s :debug :step_begin
    _prepare_proposal_target!(strategy.variable_selection, model, state, strategy)
    exhausted = _proposal_exhausted(strategy.variable_selection)
    if _proposal_reset_needed(strategy.restart, model, state, strategy, exhausted ? nothing : true)
        return _reset_proposal_state!(s, model, state, logger, strategy)
    end
    x = _proposal_target(strategy.variable_selection, s, model, state, strategy)
    x === nothing && return _reset_proposal_state!(s, model, state, logger, strategy)
    context = SearchContext(model, state, logger)
    move, rank = _best_proposal!(context, x, strategy)
    current = _current_proposal_rank(strategy.acceptance, model, state)
    event = move === nothing ? :empty : decide_move(strategy.acceptance, rank, current)
    if event !== :accepted
        _inc_last_improvement!(state)
        _proposal_event!(strategy, x, event)
        @ls_diagnostic s :trace :proposal_rejected variable=x reason=event
        @ls_diagnostic s :audit :consistency truth=_diagnostic_truth(s)
        return false
    end
    affected = _commit!(model, state, move)
    if _has_incremental(state)
        _compute_committed_costs!(model, state, affected)
    else
        _compute_costs!(model, state, affected)
    end
    solved = _finish_compute!(s, model, state, 1)
    solved || _update_unsatisfied_incumbent!(s)
    _accepted_objective!(strategy.acceptance, model, state)
    _reset_last_improvement!(state)
    _proposal_event!(strategy, x, :accepted)
    @ls_diagnostic s :trace :proposal_accepted variable=x
    @ls_diagnostic s :audit :consistency truth=_diagnostic_truth(s)
    return solved && is_sat(model)
end
