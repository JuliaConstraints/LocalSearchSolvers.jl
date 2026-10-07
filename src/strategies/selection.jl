
"""Typed policy selecting the next base variable or meta-variable target."""
abstract type AbstractVariableSelector end

"""
Retain untried maximum-error non-tabu variables after a rejected proposal.
Accepted moves, rejected plateaus and resets invalidate the remaining list.
Requires a static model and explicit move acceptance. Buffers are per trajectory.
"""
mutable struct RemainingWorstSelector <: AbstractVariableSelector
    pending::Vector{Int}
    refresh::Bool
    connected_only::Bool
end
RemainingWorstSelector(; connected_only=true) = RemainingWorstSelector(Int[], true, connected_only)
function _prepare_proposal_target!(selector::RemainingWorstSelector, model, state, strategy)
    if selector.refresh
        empty!(selector.pending)
        worst = -Inf
        excluded = tabu_list(strategy)
        variables = get_variables(model)
        feasible_opt = !is_sat(model) && iszero(get_error(state))
        for (id, cost) in pairs(_vars_costs(state))
            excluded !== nothing && haskey(excluded, id) && continue
            if selector.connected_only && !feasible_opt
                isempty(_get_constraints(_state_value(variables, id, state.indexing))) && continue
            end
            if cost > worst
                worst = cost; empty!(selector.pending); push!(selector.pending, id)
            elseif cost == worst
                push!(selector.pending, id)
            end
        end
        selector.refresh = false
    end
    return nothing
end
_prepare_proposal_target!(selector, model, state, strategy) = nothing
_proposal_exhausted(selector) = false
_proposal_exhausted(selector::RemainingWorstSelector) = isempty(selector.pending)
function _proposal_target(selector::RemainingWorstSelector, s, model, state, strategy)
    _prepare_proposal_target!(selector, model, state, strategy)
    isempty(selector.pending) && return nothing
    index = rand(eachindex(selector.pending))
    selected = selector.pending[index]
    deleteat!(selector.pending, index)
    return selected
end
_proposal_target(selector, s, model, state, strategy) = _select_target(selector, s, state, strategy)
_remaining_empty(selector) = true
_remaining_empty(selector::RemainingWorstSelector) = isempty(selector.pending)
_selection_result!(selector, event) = nothing
function _selection_result!(selector::RemainingWorstSelector, event)
    selector.refresh = event in (:accepted, :plateau_rejected, :reset)
    return nothing
end
export RemainingWorstSelector

"""Compatibility selector: choose a uniformly random maximum-error non-tabu variable."""
struct WorstVariableSelector <: AbstractVariableSelector end

"""Select the next target using a concrete variable-selection policy."""
function select_target(::WorstVariableSelector, solver)
    return _worst_target(solver.state, solver.strategies)
end

function _worst_target(state, strategies)
    candidates = _neighborhood_workspace(state).worst_variables
    return _find_rand_argmax!(
        candidates,
        _vars_costs(state),
        tabu_list(strategies);
        fallback_on_all_excluded = true
    )
end

# Dense states already guarantee that variable ids are vector positions. Mark
# exclusions once instead of hashing the tabu dictionary for every variable.
# Share the workspace's generation protocol with neighborhood construction;
# never keep marks live across a call that advances that generation.
function _worst_target(state::_State{T, I, DenseStateIndexing}, strategies) where {T, I}
    workspace = _neighborhood_workspace(state)
    candidates = workspace.worst_variables
    costs = _vars_costs(state)
    data = _state_container(costs, state.indexing)
    excluded = tabu_list(strategies)
    excluded === nothing && return _find_rand_argmax!(candidates, costs)
    if length(workspace.variable_marks) < length(data)
        previous = length(workspace.variable_marks)
        resize!(workspace.variable_marks, length(data))
        fill!(view(workspace.variable_marks, (previous + 1):length(data)), zero(UInt32))
    end
    if workspace.variable_generation == typemax(UInt32)
        fill!(workspace.variable_marks, zero(UInt32))
        workspace.variable_generation = one(UInt32)
    else
        workspace.variable_generation += one(UInt32)
    end
    generation = workspace.variable_generation
    marks = workspace.variable_marks
    for id in keys(excluded)
        1 <= id <= length(data) && (marks[id] = generation)
    end
    empty!(candidates)
    maximum_value = -Inf
    for id in eachindex(data)
        marks[id] == generation && continue
        value = data[id]
        if value > maximum_value
            maximum_value = value
            empty!(candidates)
            push!(candidates, id)
        elseif value == maximum_value
            push!(candidates, id)
        end
    end
    isempty(candidates) && return _find_rand_argmax!(candidates, costs)
    return rand(candidates)
end

# Custom selectors still receive the original solver through their public API.
_select_target(selector, solver, state, strategies) = select_target(selector, solver)
_select_target(::WorstVariableSelector, solver, state, strategies) =
    _worst_target(state, strategies)

@testitem "Worst-variable selection aspires when every variable is tabu" default_imports=false begin
    import Dictionaries: Dictionary
    import LocalSearchSolvers as LS
    import Test: @test

    candidates = Int[]
    costs = Dictionary([1, 2, 3], [1.0, 3.0, 2.0])
    excluded = Dictionary([1, 2, 3], [1, 1, 1])
    @test LS._find_rand_argmax!(
        candidates,
        costs,
        excluded;
        fallback_on_all_excluded = true
    ) == 2
end
