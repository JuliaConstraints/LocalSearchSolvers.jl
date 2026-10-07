
"""Typed runtime-depth schedule used by a neighborhood family."""
struct DepthSchedule{D <: Tuple}
    depths::D

    function DepthSchedule(depths::D) where {D <: Tuple}
        isempty(depths) && throw(ArgumentError("a depth schedule cannot be empty"))
        all(depth -> depth isa Integer && depth >= 0, depths) ||
            throw(ArgumentError("neighborhood depths must be non-negative integers"))
        return new{D}(depths)
    end
end

DepthSchedule(depths::Integer...) = DepthSchedule(map(Int, depths))

"""Original assignment neighborhood followed by one-hop swaps when needed."""
compatibility_depths() = DepthSchedule(0, 1)

Base.iterate(schedule::DepthSchedule) = iterate(schedule.depths)
Base.iterate(schedule::DepthSchedule, state) = iterate(schedule.depths, state)
Base.length(schedule::DepthSchedule) = length(schedule.depths)

"""Only changes of one variable's value; positive depths are intentionally unsupported."""
struct AssignmentNeighborhood <: AbstractNeighborhoodGenerator end
generate_moves(::AssignmentNeighborhood, request::NeighborhoodRequest) =
    generate_moves(AssignSwapNeighborhood(), request, Val(:assignment))
export AssignmentNeighborhood
