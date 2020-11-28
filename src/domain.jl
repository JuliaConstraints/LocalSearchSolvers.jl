### Abstract Domain supertype
abstract type AbstractDomain end

## Abstract Continuous Domain
abstract type ContinuousDomain{T <: AbstractFloat} <: AbstractDomain end

# Continuous Interval structure
struct ContinuousInterval{T <: AbstractFloat} <: ContinuousDomain{T}
    start::T
    stop::T
    start_open::Bool
    stop_open::Bool
end

# Continuous Intervals
struct ContinuousIntervals{T <: AbstractFloat} <: ContinuousDomain{T}
    intervals::Vector{ContinuousInterval{T}}
end

## Abstract Discrete Domain
abstract type DiscreteDomain{T <: Number} <: AbstractDomain end

# Set Domain
struct SetDomain{T <: Number} <: DiscreteDomain{T}
    points::Set{T} # TODO: should it be Indices?
end

function SetDomain(values::Vector{T}) where T <: Number
    SetDomain(Set(values))
end

# TODO: automatic conversion ?
# function SetDomain(values::OrdinalRange{T}) where T <: Number
#     SetDomain(Set(values))
# end

# Indices Domain
struct IndicesDomain{T <: Number} <: DiscreteDomain{T}
    points::Vector{T}
    inds::Dictionary{T,Int}
end

function IndicesDomain(points::Vector{T}) where T <: Number
    inds = Dictionary{T,Int}(points, 1:length(points))
    IndicesDomain(points, deepcopy(inds))
end

### Methods
_length(d::D) where D <: DiscreteDomain = length(d.points)
_get(d::IndicesDomain, index::Int) = d.points[index]
_draw(d::D) where D <: DiscreteDomain = rand(d.points)
∈(value::T, d::D) where {T <: Real,D <: DiscreteDomain} = value ∈ d.points
_delete!(d::SetDomain{T}, value::T) where {T <: Real} = pop!(d.points, value)

# TODO: implement delete! for ContinuousDomain
function _delete!(d::IndicesDomain{T}, value::T) where T <: Real
    index = get(d.inds, value, 0)
    if index > 0
        deleteat!(d.points, index)
        delete!(d.inds, value)
        map(((k,v),) -> v < index ? v : v - 1, pairs(d.inds))
    end
end

function _add!(d::SetDomain{T}, value::T) where {T <: Real}
    if !(value ∈ d)
        push!(d.points, value)
    end
end

function _add!(d::IndicesDomain{T}, value::T) where {T <: Real}
    if !(value ∈ d)
        push!(d.points, value)
        insert!(d.inds, value, length(d.points))
    end
end

_get_domain(d::D) where D <: DiscreteDomain = d.points

_domain(::Val{:set}, values::Vector) = SetDomain(values)
_domain(::Val{:indices}, values::Vector) = IndicesDomain(values)

"""
    domain(values::Vector; domain = :set)
Discrete domain constructor.
The `type` keyword can be set to `:set` (default) or `:indices`.

```julia
d1 = domain([1,2,3,4], types = :indices)
d2 = domain([53.69, 89.2, 0.12])
d3 = domain([2//3, 89//123])
```
"""
domain(values::Vector{T}; type = :set) where T <: Number = _domain(Val(type), values)