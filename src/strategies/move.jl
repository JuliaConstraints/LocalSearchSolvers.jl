
"""A typed, non-mutating description of one candidate state transition."""
abstract type AbstractMove end

"""Assign `value` to decision variable `variable`."""
struct AssignMove{T} <: AbstractMove
    variable::Int
    value::T
end

"""Exchange the values of two decision variables."""
struct SwapMove <: AbstractMove
    first::Int
    second::Int
end

"""Replace one set-valued decision through a domain-valid native edit."""
struct SetEditMove{T} <: AbstractMove
    variable::Int
    value::T
    kind::Symbol
    distance::Int
end

"""Replace one sequence-valued decision through a domain-valid native edit."""
struct SequenceEditMove{T} <: AbstractMove
    variable::Int
    value::T
    kind::Symbol
    distance::Int
end

edit_kind(move::Union{SetEditMove, SequenceEditMove}) = move.kind
edit_distance(move::Union{SetEditMove, SequenceEditMove}) = move.distance

"""
    NeighborhoodWorkspace{T}

Reusable storage owned by one search unit. The workspace deliberately knows nothing about
constraint semantics: it only stores constraint ids, atomic value changes, and tied move
candidates. Nested or parallel solvers receive distinct instances through their state.
"""
mutable struct NeighborhoodWorkspace{T}
    affected_constraints::Vector{Int}
    constraint_marks::Vector{UInt32}
    generation::UInt32
    changes::Vector{InvariantChange{T}}
    moved_variables::Vector{Int}
    moved_values::Vector{T}
    neighbor_variables::Vector{Int}
    neighbor_values::Vector{T}
    variable_marks::Vector{UInt32}
    variable_generation::UInt32
    worst_variables::Vector{Int}
    best_values::Vector{T}
    best_swaps::Vector{Int}
    restart_variables::Vector{Int}
    edit_previous::Vector{Int}
    edit_current::Vector{Int}
end

function NeighborhoodWorkspace(::Type{T}, model) where {T}
    max_constraints = _max_cons(model)
    max_variables = _max_vars(model)
    affected = Int[]
    changes = InvariantChange{T}[]
    moved_variables = Int[]
    moved_values = T[]
    neighbor_variables = Int[]
    neighbor_values = T[]
    worst_variables = Int[]
    best_values = T[]
    best_swaps = Int[]
    restart_variables = Int[]
    edit_previous = Int[]
    edit_current = Int[]
    sizehint!(affected, max_constraints)
    sizehint!(changes, maximum(c -> length(c.vars), get_constraints(model); init = 0))
    sizehint!(moved_variables, max_variables)
    sizehint!(moved_values, max_variables)
    sizehint!(neighbor_variables, max_variables)
    sizehint!(neighbor_values, max_variables)
    sizehint!(worst_variables, max_variables)
    sizehint!(best_values, max_variables)
    sizehint!(best_swaps, max_variables)
    sizehint!(restart_variables, max_variables)
    return NeighborhoodWorkspace(
        affected,
        zeros(UInt32, max_constraints),
        zero(UInt32),
        changes,
        moved_variables,
        moved_values,
        neighbor_variables,
        neighbor_values,
        zeros(UInt32, max_variables),
        zero(UInt32),
        worst_variables,
        best_values,
        best_swaps,
        restart_variables,
        edit_previous,
        edit_current,
    )
end

function _next_variable_generation!(workspace::NeighborhoodWorkspace, model)
    required = _max_vars(model)
    if length(workspace.variable_marks) < required
        previous = length(workspace.variable_marks)
        resize!(workspace.variable_marks, required)
        for index in (previous + 1):required
            workspace.variable_marks[index] = zero(UInt32)
        end
    end
    if workspace.variable_generation == typemax(UInt32)
        fill!(workspace.variable_marks, zero(UInt32))
        workspace.variable_generation = one(UInt32)
    else
        workspace.variable_generation += one(UInt32)
    end
    empty!(workspace.neighbor_variables)
    return workspace.variable_generation
end

"""Read-only vector view of an assignment after a move."""
struct MovedValues{T, V <: AbstractVector{T}, M <: AbstractMove} <: AbstractVector{T}
    values::V
    move::M
end

Base.IndexStyle(::Type{<:MovedValues}) = IndexLinear()
Base.size(values::MovedValues) = size(values.values)
function Base.getindex(values::MovedValues, variable::Int)
    value_after(values.move, values.values, variable)
end

affected_variables(move::AssignMove) = (move.variable,)
affected_variables(move::SwapMove) = (move.first, move.second)
affected_variables(move::Union{SetEditMove, SequenceEditMove}) = (move.variable,)

function value_after(move::AssignMove, values, variable)
    variable == move.variable ? move.value : values[variable]
end

function value_after(move::SwapMove, values, variable)
    variable == move.first && return values[move.second]
    variable == move.second && return values[move.first]
    return values[variable]
end

function value_after(move::Union{SetEditMove, SequenceEditMove}, values, variable)
    return variable == move.variable ? move.value : values[variable]
end

function affected_constraints(model, move::AssignMove)
    return get_cons_from_var(model, move.variable)
end

function affected_constraints(model, move::SwapMove)
    return union(get_cons_from_var(model, move.first), get_cons_from_var(model, move.second))
end

function affected_constraints(model, move::AbstractMove)
    affected = Int[]
    for variable in affected_variables(move), id in get_cons_from_var(model, variable)
        id in affected || push!(affected, id)
    end
    return affected
end

function _next_generation!(workspace::NeighborhoodWorkspace, model)
    required = _max_cons(model)
    if length(workspace.constraint_marks) < required
        previous = length(workspace.constraint_marks)
        resize!(workspace.constraint_marks, required)
        for index in (previous + 1):required
            workspace.constraint_marks[index] = zero(UInt32)
        end
    end
    if workspace.generation == typemax(UInt32)
        fill!(workspace.constraint_marks, zero(UInt32))
        workspace.generation = one(UInt32)
    else
        workspace.generation += one(UInt32)
    end
    empty!(workspace.affected_constraints)
    return workspace.generation
end

"""Collect affected constraint ids into solver-owned storage without constructing a union."""
affected_constraints!(::NeighborhoodWorkspace, model, move::AssignMove) =
    get_cons_from_var(model, move.variable)

affected_constraints!(::NeighborhoodWorkspace, model, move::AssignMove, indexing) =
    _get_constraints(_state_value(get_variables(model), move.variable, indexing))

function affected_constraints!(workspace::NeighborhoodWorkspace, model, move::AbstractMove)
    generation = _next_generation!(workspace, model)
    for variable in affected_variables(move), id in get_cons_from_var(model, variable)
        workspace.constraint_marks[id] == generation && continue
        workspace.constraint_marks[id] = generation
        push!(workspace.affected_constraints, id)
    end
    return workspace.affected_constraints
end

function affected_constraints!(
        workspace::NeighborhoodWorkspace, model, move::AbstractMove, indexing)
    generation = _next_generation!(workspace, model)
    variables = get_variables(model)
    for variable in affected_variables(move)
        constraint_ids = _get_constraints(_state_value(variables, variable, indexing))
        for id in constraint_ids
            workspace.constraint_marks[id] == generation && continue
            workspace.constraint_marks[id] = generation
            push!(workspace.affected_constraints, id)
        end
    end
    return workspace.affected_constraints
end

function invariant_changes(constraint, values, move::AssignMove)
    if length(constraint.positions) != length(constraint.vars)
        changes = InvariantChange{typeof(move.value)}[]
        for (position, variable) in pairs(constraint.vars)
            variable == move.variable || continue
            push!(changes, InvariantChange(position, values[variable], move.value))
        end
        return changes
    end
    position = constraint.positions[move.variable]
    return (InvariantChange(position, values[move.variable], move.value),)
end

function invariant_changes(constraint, values, move::SwapMove)
    if length(constraint.positions) != length(constraint.vars)
        T = typeof(values[move.first])
        changes = InvariantChange{T}[]
        for (position, variable) in pairs(constraint.vars)
            variable == move.first && push!(changes, InvariantChange(
                position, values[move.first], values[move.second]))
            variable == move.second && push!(changes, InvariantChange(
                position, values[move.second], values[move.first]))
        end
        return changes
    end
    first = get(constraint.positions, move.first, 0)
    second = get(constraint.positions, move.second, 0)
    first_change = InvariantChange(first, values[move.first], values[move.second])
    second_change = InvariantChange(second, values[move.second], values[move.first])
    iszero(first) && return (second_change,)
    iszero(second) && return (first_change,)
    return (first_change, second_change)
end

function invariant_changes(constraint, values, move::AbstractMove)
    variables = affected_variables(move)
    isempty(variables) && return InvariantChange[]
    changes = InvariantChange{typeof(values[first(variables)])}[]
    for (position, variable) in pairs(constraint.vars)
        variable in variables || continue
        push!(changes, InvariantChange(
            position, values[variable], value_after(move, values, variable)))
    end
    return changes
end

@inline function _push_change!(
        workspace::NeighborhoodWorkspace{T}, position, old_value, new_value) where {T}
    push!(workspace.changes, InvariantChange{T}(position, old_value, new_value))
    return nothing
end

invariant_changes!(::NeighborhoodWorkspace, constraint, values, move::AssignMove) =
    invariant_changes(constraint, values, move)

invariant_changes!(::NeighborhoodWorkspace, constraint, values, move::SwapMove) =
    invariant_changes(constraint, values, move)

function invariant_changes!(workspace::NeighborhoodWorkspace, constraint, values, move::AbstractMove)
    empty!(workspace.changes)
    variables = affected_variables(move)
    isempty(variables) && return workspace.changes
    for (position, variable) in pairs(constraint.vars)
        variable in variables || continue
        _push_change!(workspace,
            position, values[variable], value_after(move, values, variable))
    end
    return workspace.changes
end

@testitem "Invariant change batches preserve move depth" default_imports = false begin
    import LocalSearchSolvers as LS
    import ConstraintDomains: domain
    import Test: @test

    struct BatchMove{T, N} <: LS.AbstractMove
        variables::NTuple{N, Int}
        replacements::NTuple{N, T}
    end
    LS.affected_variables(move::BatchMove) = move.variables
    function LS.value_after(move::BatchMove, values, variable)
        position = findfirst(==(variable), move.variables)
        return isnothing(position) ? values[variable] : move.replacements[position]
    end

    repeated = LS.constraint((values; X) -> 0.0, [1, 1, 2])
    assignment = LS.invariant_changes(repeated, [5, 8], LS.AssignMove(1, 7))
    @test map(change -> change.position, assignment) == [1, 2]
    @test all(change -> change.old_value == 5 && change.new_value == 7, assignment)

    constraint = LS.constraint((values; X) -> 0.0, [1, 2, 3, 4])
    batch = BatchMove((1, 3, 4), (8, 6, 5))
    changes = LS.invariant_changes(constraint, [1, 2, 3, 4], batch)
    @test map(change -> change.position, changes) == [1, 3, 4]
    @test map(change -> change.new_value, changes) == [8, 6, 5]

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:4)), 1:4)
    LS.constraint!(model, (values; X) -> Float64(values[1] == values[2]), [1, 2])
    LS.constraint!(model, (values; X) -> Float64(values[1] == values[2]), [3, 4])
    LS.constraint!(model, LS.error_f(LS.USUAL_CONSTRAINTS[:all_different]), 1:4)
    solver = LS.solver(model; options = LS.Options(
        print_level = :silent,
        iteration = 1,
        process_threads_map = Dict(1 => 1),
    ))
    LS._init!(solver)
    workspace = LS._neighborhood_workspace(solver)
    neighbors = LS._neighbours(solver, 1, 1)
    @test neighbors === workspace.neighbor_variables
    @test Set(neighbors) == Set((2, 3, 4))
    @test length(neighbors) == 3
    affected = LS.affected_constraints!(workspace, solver, batch)
    @test affected === workspace.affected_constraints
    @test Set(affected) == Set((1, 2, 3))
    @test length(affected) == 3

    buffered = LS.invariant_changes!(
        workspace, LS.get_constraint(solver, 3), LS.get_values(solver), batch)
    @test buffered === workspace.changes
    @test map(change -> change.position, buffered) == [1, 3, 4]

    candidate = LS._candidate_cost(solver, batch)
    affected = LS._commit!(solver, batch)
    LS._compute_committed!(solver; cons_lst = affected)
    @test candidate == LS.get_error(solver)
    @test map(variable -> LS.get_value(solver, variable), batch.variables) == (8, 6, 5)

    second = LS.solver(model; options = LS.Options(
        print_level = :silent,
        iteration = 1,
        process_threads_map = Dict(1 => 1),
    ))
    LS._init!(second)
    @test LS._neighborhood_workspace(second) !== workspace
end
