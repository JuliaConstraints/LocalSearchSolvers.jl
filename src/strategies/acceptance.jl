"""Typed policy comparing a candidate rank with the best rank retained so far."""
abstract type AbstractAcceptanceStrategy end

"""Compatibility acceptance: retain strict improvements and all exact ties."""
struct BestImprovingAcceptance <: AbstractAcceptanceStrategy end

"""Return `1`, `0`, or `-1` when a candidate improves, ties, or degrades the retained rank."""
@inline function candidate_relation(::BestImprovingAcceptance, rank, best_rank)
    rank < best_rank && return Int8(1)
    rank == best_rank && return Int8(0)
    return Int8(-1)
end

"""Acceptance policies with an explicit accept/reject decision after proposal ranking."""
abstract type ExplicitMoveAcceptance <: AbstractAcceptanceStrategy end

"""
    GreedyPlateauAcceptance(; reject_plateau_percent=10, guide_infeasible=true)

Accept smaller constraint error; for equal error compare the minimization-normalized
objective, then reject exact plateaus with the given percentage. With
`guide_infeasible=true`, objective guidance also ranks infeasible candidates.
Its cached objective belongs to one trajectory and is initialized by `solve!`.
"""
mutable struct GreedyPlateauAcceptance{GuideInfeasible} <: ExplicitMoveAcceptance
    reject_plateau_percent::Int
    current_objective::Float64
    function GreedyPlateauAcceptance(; reject_plateau_percent=10, guide_infeasible=true)
        0 <= reject_plateau_percent <= 100 || throw(ArgumentError("plateau percentage must be in 0:100"))
        new{guide_infeasible}(reject_plateau_percent, Inf)
    end
end

@inline _guide_infeasible(::GreedyPlateauAcceptance{G}) where {G} = G
@inline function decide_move(a::GreedyPlateauAcceptance, proposed, current, rng=Random.default_rng())
    proposed < current && return :accepted
    proposed > current && return :rejected
    proposed == current || return :rejected # NaN is never an improvement or plateau.
    return rand(rng, 1:100) <= a.reject_plateau_percent ? :plateau_rejected : :accepted
end

export ExplicitMoveAcceptance, GreedyPlateauAcceptance, decide_move
