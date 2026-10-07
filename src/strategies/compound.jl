"""
    NativeDecisionNeighborhood

Neighborhood for set- and sequence-valued variables. Depth is zero-based: depth `0`
contains one native edit, while depth `d` contains decisions no farther than `d + 1`
edits. Every emitted value already belongs to the variable domain.
"""
struct NativeDecisionNeighborhood <: AbstractNeighborhoodGenerator end

struct SetEditMoveIterator{T, V, W}
    target::Int
    old_value::T
    values::V
    radius::Int
    workspace::W
end

struct SequenceEditMoveIterator{T, V, W}
    target::Int
    old_value::T
    values::V
    radius::Int
    workspace::W
end

Base.IteratorSize(::Type{<:SetEditMoveIterator}) = Base.SizeUnknown()
Base.IteratorSize(::Type{<:SequenceEditMoveIterator}) = Base.SizeUnknown()
Base.eltype(::Type{<:SetEditMoveIterator{T}}) where {T} = SetEditMove{T}
Base.eltype(::Type{<:SequenceEditMoveIterator{T}}) where {T} = SequenceEditMove{T}

@inline function _set_edit(old_value, new_value)
    removed = 0
    inserted = 0
    for value in old_value
        value in new_value || (removed += 1)
    end
    for value in new_value
        value in old_value || (inserted += 1)
    end
    distance = max(removed, inserted)
    kind = if iszero(distance)
        :identity
    elseif distance > 1
        :composite
    elseif iszero(removed)
        :insert
    elseif iszero(inserted)
        :delete
    else
        :exchange
    end
    return kind, distance
end

@inline function _single_insertion(shorter, longer)
    length(longer) == length(shorter) + 1 || return false
    short_index = firstindex(shorter)
    long_index = firstindex(longer)
    skipped = false
    while short_index <= lastindex(shorter)
        if shorter[short_index] == longer[long_index]
            short_index += 1
            long_index += 1
        elseif skipped
            return false
        else
            skipped = true
            long_index += 1
        end
    end
    return true
end

@inline function _sequence_atomic_kind(old_value, new_value)
    old_length = length(old_value)
    new_length = length(new_value)
    new_length == old_length + 1 &&
        return _single_insertion(old_value, new_value) ? :insert : :composite
    old_length == new_length + 1 &&
        return _single_insertion(new_value, old_value) ? :delete : :composite
    old_length == new_length || return :composite

    first_difference = 0
    last_difference = 0
    differences = 0
    for index in eachindex(old_value, new_value)
        old_value[index] == new_value[index] && continue
        iszero(first_difference) && (first_difference = index)
        last_difference = index
        differences += 1
    end
    iszero(differences) && return :identity
    differences == 1 && return :replace
    if differences == 2 &&
       old_value[first_difference] == new_value[last_difference] &&
       old_value[last_difference] == new_value[first_difference]
        return :swap
    end
    for offset in 0:(last_difference - first_difference)
        old_value[first_difference + offset] == new_value[last_difference - offset] ||
            return :composite
    end
    return :reverse
end

function _edit_rows!(workspace::NeighborhoodWorkspace, required::Int)
    resize!(workspace.edit_previous, required)
    resize!(workspace.edit_current, required)
    return workspace.edit_previous, workspace.edit_current
end

"""Levenshtein upper bound backed by solver-owned rows."""
function _sequence_edit_distance!(workspace::NeighborhoodWorkspace, old_value, new_value)
    if length(old_value) > length(new_value)
        return _sequence_edit_distance!(workspace, new_value, old_value)
    end
    columns = length(old_value) + 1
    previous, current = _edit_rows!(workspace, columns)
    for column in 1:columns
        @inbounds previous[column] = column - 1
    end
    for (row, new_item) in enumerate(new_value)
        @inbounds current[1] = row
        for (column, old_item) in enumerate(old_value)
            # Both rows are solver-owned and resized to length(old_value) + 1.
            @inbounds begin
                substitution = previous[column] + (old_item == new_item ? 0 : 1)
                current[column + 1] = min(
                    current[column] + 1,
                    previous[column + 1] + 1,
                    substitution,
                )
            end
        end
        previous, current = current, previous
    end
    @inbounds return previous[columns]
end

@inline function _next_set_edit(iterator::SetEditMoveIterator{T}, next) where {T}
    while !isnothing(next)
        value, state = next
        kind, distance = _set_edit(iterator.old_value, value)
        if 0 < distance <= iterator.radius
            return SetEditMove{T}(iterator.target, value, kind, distance), state
        end
        next = iterate(iterator.values, state)
    end
    return nothing
end


@inline function _next_sequence_edit(iterator::SequenceEditMoveIterator{T}, next) where {T}
    while !isnothing(next)
        value, state = next
        kind = _sequence_atomic_kind(iterator.old_value, value)
        distance = kind === :identity ? 0 :
                   kind === :composite ? _sequence_edit_distance!(
                       iterator.workspace, iterator.old_value, value) : 1
        if 0 < distance <= iterator.radius
            return SequenceEditMove{T}(iterator.target, value, kind, distance), state
        end
        next = iterate(iterator.values, state)
    end
    return nothing
end

Base.iterate(iterator::SetEditMoveIterator) =
    _next_set_edit(iterator, iterate(iterator.values))
Base.iterate(iterator::SetEditMoveIterator, state) =
    _next_set_edit(iterator, iterate(iterator.values, state))
Base.iterate(iterator::SequenceEditMoveIterator) =
    _next_sequence_edit(iterator, iterate(iterator.values))
Base.iterate(iterator::SequenceEditMoveIterator, state) =
    _next_sequence_edit(iterator, iterate(iterator.values, state))

function generate_moves(::NativeDecisionNeighborhood, request::NeighborhoodRequest)
    context = request.context
    target = Int(request.target)
    variable = _state_value(
        get_variables(context.model), target, context.state.indexing)
    old_value = _value(context.state, target)
    values = get_domain(variable)
    radius = request.depth + 1
    workspace = _neighborhood_workspace(context.state)
    domain = variable.domain
    if domain isa SetDecisionDomain
        return SetEditMoveIterator(target, old_value, values, radius, workspace)
    elseif domain isa SequenceDecisionDomain
        return SequenceEditMoveIterator(target, old_value, values, radius, workspace)
    end
    throw(ArgumentError(
        "NativeDecisionNeighborhood requires a set- or sequence-decision domain"))
end

function _native_decision_move!(context, target::Int,
        acceptance, depth::Int, domain::SetDecisionDomain)
    state = context.state
    workspace = _neighborhood_workspace(state)
    old_value = _value(state, target)
    best_values = workspace.best_values
    best_swaps = workspace.best_swaps
    empty!(best_values)
    push!(best_values, old_value)
    empty!(best_swaps)
    push!(best_swaps, target)
    tabu = true
    best_rank = (get_error(state), _optimizing(state) ? get_value(state) : Inf)
    radius = depth + 1
    for value in ConstraintDomains.get_domain(domain)
        kind, distance = _set_edit(old_value, value)
        0 < distance <= radius || continue
        move = SetEditMove(target, value, kind, distance)
        rank = _candidate_rank(context, move)
        relation = candidate_relation(acceptance, rank, best_rank)
        if relation > 0
            tabu = false
            best_rank = rank
            empty!(best_values)
            push!(best_values, value)
        elseif iszero(relation)
            push!(best_values, value)
        end
        iszero(rank[1]) && is_sat(context.model) && break
    end
    return best_values, best_swaps, tabu
end

function _native_decision_move!(context, target::Int,
        acceptance, depth::Int, domain::SequenceDecisionDomain)
    state = context.state
    workspace = _neighborhood_workspace(state)
    old_value = _value(state, target)
    best_values = workspace.best_values
    best_swaps = workspace.best_swaps
    empty!(best_values)
    push!(best_values, old_value)
    empty!(best_swaps)
    push!(best_swaps, target)
    tabu = true
    best_rank = (get_error(state), _optimizing(state) ? get_value(state) : Inf)
    radius = depth + 1
    for value in ConstraintDomains.get_domain(domain)
        kind = _sequence_atomic_kind(old_value, value)
        distance = kind === :identity ? 0 :
                   kind === :composite ?
                   _sequence_edit_distance!(workspace, old_value, value) : 1
        0 < distance <= radius || continue
        move = SequenceEditMove(target, value, kind, distance)
        rank = _candidate_rank(context, move)
        relation = candidate_relation(acceptance, rank, best_rank)
        if relation > 0
            tabu = false
            best_rank = rank
            empty!(best_values)
            push!(best_values, value)
        elseif iszero(relation)
            push!(best_values, value)
        end
        iszero(rank[1]) && is_sat(context.model) && break
    end
    return best_values, best_swaps, tabu
end

function _native_decision_move!(context, target::Int, acceptance, depth::Int)
    variable = _state_value(
        get_variables(context.model), target, context.state.indexing)
    domain = variable.domain
    domain isa Union{SetDecisionDomain, SequenceDecisionDomain} ||
        throw(ArgumentError(
            "NativeDecisionNeighborhood requires a set- or sequence-decision domain"))
    return _native_decision_move!(context, target, acceptance, depth, domain)
end

@testitem "Native set and sequence decision neighborhoods" default_imports=false begin
    import ConstraintDomains: sequence_domain, set_decision_domain
    import LocalSearchSolvers as LS
    import Test: @test

    set_model = LS.model()
    LS.variable!(set_model, set_decision_domain((
        Set((:a,)),
        Set((:a, :b)),
        Set((:b,)),
        Set((:b, :c, :d)),
    )))
    LS.constraint!(set_model,
        (values; X) -> length(setdiff(Set((:a, :b)), values[1])) +
                         length(setdiff(values[1], Set((:a, :b)))),
        [1],
    )
    set_strategy = LS.MetaStrategy(set_model;
        neighborhood = LS.NativeDecisionNeighborhood(),
        depths = LS.DepthSchedule(0),
    )
    set_solver = LS.solver(set_model; strategies = set_strategy, options = LS.Options(
        print_level = :silent, iteration = 1, process_threads_map = Dict(1 => 1)))
    LS._init!(set_solver)
    LS._value!(set_solver, 1, Set((:a,)))
    LS._compute!(set_solver)
    set_request = LS.NeighborhoodRequest(LS._search_context(set_solver), 1, 0, nothing)
    set_moves = collect(LS.generate_moves(LS.NativeDecisionNeighborhood(), set_request))
    @test map(LS.edit_kind, set_moves) == [:insert, :exchange]
    @test all(move -> move.value in LS.get_variable(set_solver, 1), set_moves)
    set_candidate = first(set_moves)
    candidate_cost = LS._candidate_cost(set_solver, set_candidate)
    affected = LS._commit!(set_solver, set_candidate)
    LS._compute!(set_solver; cons_lst = affected)
    @test candidate_cost == LS.get_error(set_solver) == 0.0

    sequence_model = LS.model()
    LS.variable!(sequence_model, sequence_domain((
        [:a, :b, :c, :d],
        [:a, :c, :b, :d],
        [:d, :c, :b, :a],
        [:a, :b, :c, :d, :e],
        [:e, :d, :c, :b, :a],
        [:x, :c, :b, :y],
    )))
    LS.constraint!(sequence_model,
        (values; X) -> values[1] == [:d, :c, :b, :a] ? 0.0 : 1.0,
        [1],
    )
    sequence_strategy = LS.MetaStrategy(sequence_model;
        neighborhood = LS.NativeDecisionNeighborhood(),
        depths = LS.DepthSchedule(0),
    )
    sequence_solver = LS.solver(sequence_model;
        strategies = sequence_strategy,
        options = LS.Options(
            print_level = :silent, iteration = 1, process_threads_map = Dict(1 => 1)))
    LS._init!(sequence_solver)
    LS._value!(sequence_solver, 1, [:a, :b, :c, :d])
    LS._compute!(sequence_solver)
    sequence_request = LS.NeighborhoodRequest(
        LS._search_context(sequence_solver), 1, 0, nothing)
    sequence_moves = collect(LS.generate_moves(
        LS.NativeDecisionNeighborhood(), sequence_request))
    @test map(LS.edit_kind, sequence_moves) == [:swap, :reverse, :insert]
    @test all(move -> LS.edit_distance(move) == 1, sequence_moves)
    reverse_move = only(filter(move -> LS.edit_kind(move) === :reverse, sequence_moves))
    reverse_cost = LS._candidate_cost(sequence_solver, reverse_move)
    affected = LS._commit!(sequence_solver, reverse_move)
    LS._compute!(sequence_solver; cons_lst = affected)
    @test reverse_cost == LS.get_error(sequence_solver) == 0.0

    deep_request = LS.NeighborhoodRequest(
        LS._search_context(sequence_solver), 1, 2, nothing)
    deep_moves = collect(LS.generate_moves(LS.NativeDecisionNeighborhood(), deep_request))
    @test all(move -> LS.edit_distance(move) <= 3, deep_moves)
    @test any(move -> LS.edit_kind(move) === :composite &&
                      LS.edit_distance(move) == 2, deep_moves)
end
