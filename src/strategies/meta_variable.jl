"""Interface for a solver-independent subproblem scope."""
abstract type AbstractMetaVariable end

"""
    MetaVariable

A possibly overlapping group of base variables. It describes a subproblem scope but owns no
solver and enumerates no domain of complete assignments.
"""
struct MetaVariable{P} <: AbstractMetaVariable
    id::Symbol
    variables::Vector{Int}
    provenance::P
end

@testitem "Meta-move batch deltas cover sum, noOverlap, and cumulative" default_imports=false begin
    import ConstraintDomains: domain
    import Constraints
    import LocalSearchSolvers as LS
    import Test: @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(0:12)), 1:5)
    sum_error = Constraints.bind_error(
        Constraints.make_error(:sum);
        op = <=,
        pair_vars = [2, -1, 3, 1],
        val = 25,
    )
    scheduling_error = Constraints.bind_error(
        Constraints.make_error(:no_overlap);
        pair_vars = [2, 3, 1, 2],
        dim = 1,
        bool = true,
    )
    resource_error = Constraints.bind_error(
        Constraints.make_error(:cumulative);
        pair_vars = [2 3 1 2 2; 1 2 1 1 2],
        op = <=,
        val = 3,
    )
    LS.constraint!(model, sum_error, [1, 2, 3, 4])
    LS.constraint!(model, scheduling_error, [2, 3, 4, 5])
    LS.constraint!(model, resource_error, [1, 2, 3, 4, 5])
    solver = LS.solver(model; options = LS.Options(
        print_level = :silent,
        iteration = 1,
        process_threads_map = Dict(1 => 1),
    ))
    LS._init!(solver)
    for (variable, value) in enumerate((0, 3, 6, 8, 11))
        LS._value!(solver, variable, value)
    end
    LS._compute!(solver)

    group = LS.MetaVariable(:repair, [1, 2, 3, 4, 5])
    move = LS.MetaMove(group, [1, 3, 4, 5], [4, 4, 9, 10])
    original_values = collect(LS.get_values(solver))
    original_costs = collect(LS._cons_costs(solver))
    candidate = LS._candidate_cost(solver, move)
    @test collect(LS.get_values(solver)) == original_values
    @test collect(LS._cons_costs(solver)) == original_costs

    affected = LS._commit!(solver, move)
    LS._compute_committed!(solver; cons_lst = affected)
    @test candidate == LS.get_error(solver)
    @test Set(affected) == Set((1, 2, 3))
    @test all(id -> Constraints.supports_incremental(LS._invariant(solver, id)), affected)

    incremental_cost = LS.get_error(solver)
    LS._compute!(solver)
    @test LS.get_error(solver) == incremental_cost
end

# A plain integer vector still needs an owned copy, but no argument expansion or conversion.
_owned_variable_ids(variables::Vector{Int}) = copy(variables)
_owned_variable_ids(variables) = Int[variables...]

function MetaVariable(id::Symbol, variables;
        provenance = (source = :explicit,))
    collected = sort!(_owned_variable_ids(variables))
    isempty(collected) && throw(ArgumentError("a meta-variable scope cannot be empty"))
    all(>(0), collected) ||
        throw(ArgumentError("meta-variable ids must be strictly positive"))
    allunique(collected) ||
        throw(ArgumentError("a meta-variable cannot contain a base variable twice"))
    return MetaVariable(id, collected, provenance)
end

scope(variable::MetaVariable) = variable.variables
meta_variable_id(variable::MetaVariable) = variable.id

"""
    MetaMove

The atomic parent-level result of resolving a meta-variable. Variable ids are sorted once at
construction, outside candidate evaluation, so value lookup is allocation-free and logarithmic.
"""
struct MetaMove{T, P} <: AbstractMove
    meta_variable::Symbol
    variables::Vector{Int}
    replacements::Vector{T}
    provenance::P
end

_move_inside_scope(variable::AbstractMetaVariable, ids) =
    all(id -> id in scope(variable), ids)
function _move_inside_scope(variable::MetaVariable, ids)
    variables = scope(variable)
    # Public scopes can be edited after construction. Preserve membership semantics when
    # their original sorted order is no longer present.
    issorted(variables) || return all(id -> id in variables, ids)
    position = firstindex(variables)
    for id in ids
        while position <= lastindex(variables) && variables[position] < id
            position += 1
        end
        (position > lastindex(variables) || variables[position] != id) && return false
    end
    return true
end

function MetaMove(variable::AbstractMetaVariable, variables, replacements;
        provenance = (source = :subproblem,))
    ids = _owned_variable_ids(variables)
    values = collect(replacements)
    length(ids) == length(values) ||
        throw(DimensionMismatch("a meta-move needs one replacement per variable"))
    isempty(ids) && throw(ArgumentError("a meta-move cannot be empty"))
    # These vectors are already owned. Sorted requests need no permutation or second copy.
    # Keep the original indexing path for non-vector replacement collections.
    sorted_ids, sorted_values = if values isa Vector && issorted(ids)
        ids, values
    else
        order = sortperm(ids)
        ids[order], values[order]
    end
    allunique(sorted_ids) ||
        throw(ArgumentError("a meta-move cannot change a variable twice"))
    _move_inside_scope(variable, sorted_ids) ||
        throw(ArgumentError("a meta-move must stay inside its meta-variable scope"))
    return MetaMove(meta_variable_id(variable), sorted_ids, sorted_values, provenance)
end

"""
    MetaMove(variable, replacements::AbstractVector; provenance)

Build a full-scope move when `replacements` already follows `scope(variable)` order. The
general partial-move constructor sorts and validates arbitrary variable ids; this overload
avoids that work while still copying both vectors so the move owns an independent snapshot.
"""
function MetaMove(variable::AbstractMetaVariable, replacements::AbstractVector;
        provenance = (source = :subproblem,))
    variables = scope(variable)
    length(variables) == length(replacements) ||
        throw(DimensionMismatch("a full-scope meta-move needs one replacement per variable"))
    return MetaMove(
        meta_variable_id(variable),
        _owned_variable_ids(variables),
        collect(replacements),
        provenance,
    )
end

function MetaMove(variable::AbstractMetaVariable, replacements::AbstractDict;
        provenance = (source = :subproblem,))
    return MetaMove(variable, keys(replacements), values(replacements); provenance)
end

meta_variable(move::MetaMove) = move.meta_variable
move_depth(move::AbstractMove) = length(affected_variables(move))
affected_variables(move::MetaMove) = move.variables

@inline function _replacement_index(move::MetaMove, variable::Int)
    index = searchsortedfirst(move.variables, variable)
    return index <= length(move.variables) && move.variables[index] == variable ? index : 0
end

@inline function value_after(move::MetaMove, values, variable)
    index = _replacement_index(move, variable)
    return iszero(index) ? values[variable] : move.replacements[index]
end

function invariant_changes!(
        workspace::NeighborhoodWorkspace, constraint, values, move::MetaMove)
    empty!(workspace.changes)
    for (position, variable) in pairs(constraint.vars)
        index = _replacement_index(move, variable)
        iszero(index) && continue
        _push_change!(workspace,
            position, values[variable], move.replacements[index])
    end
    return workspace.changes
end

"""A strategy family that generates typed moves into caller-owned storage."""
abstract type AbstractNeighborhoodGenerator end

"""A runtime-depth neighborhood request. Depth is data, not part of the generator type."""
struct NeighborhoodRequest{C, T, R}
    context::C
    target::T
    depth::Int
    rng::R

    function NeighborhoodRequest(context::C, target::T, depth::Integer, rng::R) where {
            C, T, R}
        depth >= 0 || throw(ArgumentError("neighborhood depth must be non-negative"))
        return new{C, T, R}(context, target, Int(depth), rng)
    end
end

"""Fill caller-owned `output` with moves for one neighborhood request."""
function generate_moves! end

"""Return a typed, possibly lazy move sequence for one neighborhood request."""
function generate_moves end

"""
    AssignSwapNeighborhood

Compatibility generator for the original LocalSearchSolvers neighborhood. Depth zero produces
assignments from the selected variable domain; every positive depth produces the original
one-hop compatible swaps through incident constraints. Other generators may give deeper values
their graph-radius meaning.
"""
struct AssignSwapNeighborhood <: AbstractNeighborhoodGenerator end

struct AssignmentMoveIterator{T, V}
    target::Int
    old_value::T
    values::V
end

Base.IteratorSize(::Type{<:AssignmentMoveIterator}) = Base.SizeUnknown()
Base.eltype(::Type{<:AssignmentMoveIterator{T}}) where {T} = AssignMove{T}

@inline function _next_assignment(iterator::AssignmentMoveIterator{T}, next) where {T}
    while !isnothing(next)
        value, state = next
        value == iterator.old_value ||
            return AssignMove{T}(iterator.target, value), state
        next = iterate(iterator.values, state)
    end
    return nothing
end

Base.iterate(iterator::AssignmentMoveIterator) =
    _next_assignment(iterator, iterate(iterator.values))
Base.iterate(iterator::AssignmentMoveIterator, state) =
    _next_assignment(iterator, iterate(iterator.values, state))

struct SwapMoveIterator{V}
    target::Int
    variables::V
end

Base.IteratorSize(::Type{<:SwapMoveIterator}) = Base.SizeUnknown()
Base.eltype(::Type{<:SwapMoveIterator}) = SwapMove
Base.iterate(iterator::SwapMoveIterator) = _next_swap(iterator, iterate(iterator.variables))
Base.iterate(iterator::SwapMoveIterator, state) =
    _next_swap(iterator, iterate(iterator.variables, state))
@inline _next_swap(::SwapMoveIterator, ::Nothing) = nothing
@inline _next_swap(iterator::SwapMoveIterator, next) =
    (SwapMove(iterator.target, first(next)), last(next))

function generate_moves(
        ::AssignSwapNeighborhood, request::NeighborhoodRequest, ::Val{:assignment})
    request.depth == 0 || throw(ArgumentError("assignment neighborhoods require depth zero"))
    context = request.context
    target = Int(request.target)
    old_value = _value(context.state, target)
    values = _neighbours(context, target, 0)
    return AssignmentMoveIterator(target, old_value, values)
end

function generate_moves(
        ::AssignSwapNeighborhood, request::NeighborhoodRequest, ::Val{:swap})
    request.depth > 0 || throw(ArgumentError("swap neighborhoods require positive depth"))
    context = request.context
    target = Int(request.target)
    variables = _neighbours(context, target, request.depth)
    return SwapMoveIterator(target, variables)
end

generate_moves(generator::AssignSwapNeighborhood, request::NeighborhoodRequest) =
    request.depth == 0 ? generate_moves(generator, request, Val(:assignment)) :
    generate_moves(generator, request, Val(:swap))

generate_moves(generator::AbstractNeighborhoodGenerator, request::NeighborhoodRequest, ::Val) =
    generate_moves(generator, request)

function generate_moves!(output, generator::AbstractNeighborhoodGenerator,
        request::NeighborhoodRequest)
    empty!(output)
    for move in generate_moves(generator, request)
        push!(output, move)
    end
    return output
end

"""A solver adapter capable of resolving one meta-variable under an explicit budget."""
abstract type AbstractMetaVariableResolver end

"""Snapshot, budget and RNG passed to a solver-independent meta-variable resolver."""
struct MetaVariableRequest{M <: AbstractMetaVariable, S, B, R}
    variable::M
    snapshot::S
    budget::B
    rng::R
end

"""Resolve a meta-variable request into an atomic parent-level move."""
function resolve_meta_variable end

@testitem "Meta-variable moves are atomic and extensible" default_imports=false begin
    import ConstraintDomains: domain
    import Constraints
    import LocalSearchSolvers as LS
    import Test: @test, @test_throws

    first_group = LS.MetaVariable(
        :left, [3, 1, 2]; provenance = (source = :graph, layer = 1))
    second_group = LS.MetaVariable(:right, [3, 4])
    @test LS.scope(first_group) == [1, 2, 3]
    @test intersect(LS.scope(first_group), LS.scope(second_group)) == [3]
    @test_throws ArgumentError LS.MetaVariable(:duplicate, [1, 1])

    move = LS.MetaMove(first_group, [3, 1], [7, 8])
    @test LS.affected_variables(move) == [1, 3]
    @test move.replacements == [8, 7]
    @test LS.move_depth(move) == 2
    @test LS.meta_variable(move) == :left
    @test LS.value_after(move, [1, 2, 3, 4], 1) == 8
    @test LS.value_after(move, [1, 2, 3, 4], 2) == 2
    @test_throws ArgumentError LS.MetaMove(first_group, [4], [9])
    full_replacements = [8, 2, 7]
    full_move = LS.MetaMove(first_group, full_replacements)
    full_replacements[1] = 1
    LS.scope(first_group)[1] = 4
    @test full_move.variables == [1, 2, 3]
    @test full_move.replacements == [8, 2, 7]
    LS.scope(first_group)[1] = 1
    @test_throws DimensionMismatch LS.MetaMove(first_group, [1, 2])

    struct FixtureGenerator <: LS.AbstractNeighborhoodGenerator end
    function LS.generate_moves!(output, ::FixtureGenerator, request::LS.NeighborhoodRequest)
        empty!(output)
        request.depth > 0 && push!(output, move)
        return output
    end
    request = LS.NeighborhoodRequest(:context, first_group, 2, nothing)
    output = typeof(move)[]
    @test LS.generate_moves!(output, FixtureGenerator(), request) == [move]
    @test_throws ArgumentError LS.NeighborhoodRequest(:context, first_group, -1, nothing)

    struct FixtureResolver <: LS.AbstractMetaVariableResolver end
    function LS.resolve_meta_variable(::FixtureResolver, request::LS.MetaVariableRequest)
        return LS.MetaMove(request.variable, [1, 3], [8, 7])
    end
    resolved = LS.resolve_meta_variable(FixtureResolver(),
        LS.MetaVariableRequest(first_group, [1, 2, 3], (iterations = 10,), nothing))
    @test resolved.variables == [1, 3]

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:8)), 1:4)
    LS.constraint!(model, Constraints.make_error(:all_different), 1:4)
    solver = LS.solver(model;
        options = LS.Options(
            print_level = :silent,
            iteration = 1,
            process_threads_map = Dict(1 => 1)
        ))
    LS._init!(solver)
    context = LS._search_context(solver)
    assignment_reference = [LS.AssignMove(1, value)
                            for value in LS._neighbours(context, 1, 0)
                            if value != LS.get_value(solver, 1)]
    assignment_request = LS.NeighborhoodRequest(context, 1, 0, nothing)
    assignment_output = LS.AssignMove{Int}[]
    @test LS.generate_moves!(
        assignment_output, LS.AssignSwapNeighborhood(), assignment_request
    ) === assignment_output
    @test assignment_output == assignment_reference
    @test collect(LS.generate_moves(LS.AssignSwapNeighborhood(), assignment_request)) ==
          assignment_reference

    swap_reference = [LS.SwapMove(1, variable)
                      for variable in LS._neighbours(context, 1, 1)]
    swap_request = LS.NeighborhoodRequest(context, 1, 1, nothing)
    swap_output = LS.SwapMove[]
    @test LS.generate_moves!(swap_output, LS.AssignSwapNeighborhood(), swap_request) ===
          swap_output
    @test swap_output == swap_reference
    @test collect(LS.generate_moves(LS.AssignSwapNeighborhood(), swap_request)) == swap_reference
    @test_throws ArgumentError collect(LS.generate_moves(
        LS.AssignSwapNeighborhood(),
        LS.NeighborhoodRequest(context, 1, 1, nothing),
        Val(:assignment)
    ))
    depth_one = LS._move!(context, 1, LS.AssignSwapNeighborhood(), 1)
    depth_one_snapshot = (copy(depth_one[1]), copy(depth_one[2]), depth_one[3])
    depth_two = LS._move!(context, 1, LS.AssignSwapNeighborhood(), 2)
    @test (copy(depth_two[1]), copy(depth_two[2]), depth_two[3]) == depth_one_snapshot
    @test_throws ArgumentError LS._move!(context, 1, LS.AssignSwapNeighborhood(), -1)

    struct EmptyTrackedGenerator <: LS.AbstractNeighborhoodGenerator
        calls::Base.RefValue{Int}
    end
    function LS.generate_moves(
            generator::EmptyTrackedGenerator, ::LS.NeighborhoodRequest)
        generator.calls[] += 1
        return LS.AssignMove{Int}[]
    end
    calls = Ref(0)
    LS._move!(context, 1, EmptyTrackedGenerator(calls), 0)
    @test calls[] == 1

    original = collect(LS.get_values(solver))
    candidate = LS._candidate_cost(solver, move)
    @test collect(LS.get_values(solver)) == original
    affected = LS._commit!(solver, move)
    LS._compute_committed!(solver; cons_lst = affected)
    @test LS.get_value(solver, 1) == 8
    @test LS.get_value(solver, 3) == 7
    @test candidate == LS.get_error(solver)
end
