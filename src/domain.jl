### Abstract Domain supertype
abstract type AbstractDomain end

## Abstract Continuous Domain
abstract type ContinuousDomain {T <: AbstractFloat} <: AbstractDomain end

# Continuous Interval structure
struct ContinuousInterval {T <: AbstractFloat} <: ContinuousInterval{T}
    start::T
    stop::T
    start_open::Bool
    stop_open::Bool
end

# Continuous Intervals
struct ContinuousInterval {T <: AbstractFloat} <: ContinuousInterval{T}
    intervals::Vector{ContinuousInterval{T}}
end

## Abstract Discrete Domain
abstract type DiscreteDomain {T <: Number} end

# Set Domain
struct SetDomain{T <: Number} <: DiscreteDomain{T}
    points::Set{T} # TODO: should it be Indices?
end

function SetDomain(values::Vector{T}) where T <: Number
    SetDomain(Set(values))
end
function SetDomain(values::OrdinalRange{T}) where T <: Number
    SetDomain(Set(values))
end

# Indices Domain
struct IndicesDomain{T <: Number} <: DiscreteDomain{T}
    points::Vector{T}
    inds::Dictionary{T,Int}
end

function IndicesDomain(points::Vector{T}) where T <: Number
    inds = Dictionary{T,Int}(points, 1:length(points))
    IndexesDomain(points, deepcopy(inds))
end

### Methods
_length(d::D) where D <: DiscreteDomain = length(d.points)
_get(d::IndexesDomain, index::Int) = d.points[index]
_draw(d::D) where D <: DiscreteDomain = rand(d.points)
∈(value::T, d::D) where {T <: Real,D <: DiscreteDomain} = value ∈ d.points
_delete!(d::SetDomain{T}, value::T) where {T <: Real} = pop!(d.points, value)

# TODO: implement delete! for ContinuousDomain
function _delete!(d::IndexesDomain{T}, value::T) where T <: Real
    index = get(d.indexes, value, 0)
    if index > 0
        deleteat!(d.points, index)
        delete!(d.indexes, value)
        map(((k,v),) -> v < index ? v : v - 1, pairs(d.indexes))
    end
end

function _add!(d::SetDomain{T}, value::T) where {T <: Real}
    if !(value ∈ d)
        push!(d.points, value)
    end
end

function _add!(d::IndexesDomain{T}, value::T) where {T <: Real}
    if !(value ∈ d)
        push!(d.points, value)
        insert!(d.indexes, value, length(d.points))
    end
end
