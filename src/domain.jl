### Abstract Domain supertype
abstract type AbstractDomain end

## Abstract Continuous Domain
<<<<<<< HEAD
<<<<<<< HEAD
abstract type ContinuousDomain{T <: AbstractFloat} <: AbstractDomain end

# Continuous Interval structure
struct ContinuousInterval{T <: AbstractFloat} <: ContinuousDomain{T}
=======
abstract type ContinuousDomain {T <: AbstractFloat} <: AbstractDomain end

# Continuous Interval structure
struct ContinuousInterval {T <: AbstractFloat} <: ContinuousInterval{T}
>>>>>>> Added domain structures and methods
=======
abstract type ContinuousDomain{T <: AbstractFloat} <: AbstractDomain end

# Continuous Interval structure
struct ContinuousInterval{T <: AbstractFloat} <: ContinuousDomain{T}
>>>>>>> Test for domain types and methods. Added Dictionaries.jl
    start::T
    stop::T
    start_open::Bool
    stop_open::Bool
end

# Continuous Intervals
<<<<<<< HEAD
<<<<<<< HEAD
struct ContinuousIntervals{T <: AbstractFloat} <: ContinuousDomain{T}
=======
struct ContinuousInterval {T <: AbstractFloat} <: ContinuousInterval{T}
>>>>>>> Added domain structures and methods
=======
struct ContinuousIntervals{T <: AbstractFloat} <: ContinuousDomain{T}
>>>>>>> Test for domain types and methods. Added Dictionaries.jl
    intervals::Vector{ContinuousInterval{T}}
end

## Abstract Discrete Domain
<<<<<<< HEAD
<<<<<<< HEAD
abstract type DiscreteDomain{T <: Number} <: AbstractDomain end
=======
abstract type DiscreteDomain {T <: Number} end
>>>>>>> Added domain structures and methods
=======
abstract type DiscreteDomain{T <: Number} end
>>>>>>> Test for domain types and methods. Added Dictionaries.jl

# Set Domain
struct SetDomain{T <: Number} <: DiscreteDomain{T}
    points::Set{T} # TODO: should it be Indices?
end

function SetDomain(values::Vector{T}) where T <: Number
    SetDomain(Set(values))
end
<<<<<<< HEAD

# TODO: automatic conversion ?
# function SetDomain(values::OrdinalRange{T}) where T <: Number
#     SetDomain(Set(values))
# end
=======
function SetDomain(values::OrdinalRange{T}) where T <: Number
    SetDomain(Set(values))
end
>>>>>>> Added domain structures and methods

# Indices Domain
struct IndicesDomain{T <: Number} <: DiscreteDomain{T}
    points::Vector{T}
    inds::Dictionary{T,Int}
end

function IndicesDomain(points::Vector{T}) where T <: Number
    inds = Dictionary{T,Int}(points, 1:length(points))
<<<<<<< HEAD
<<<<<<< HEAD
    IndicesDomain(points, deepcopy(inds))
=======
    IndexesDomain(points, deepcopy(inds))
>>>>>>> Added domain structures and methods
=======
    IndicesDomain(points, deepcopy(inds))
>>>>>>> Test for domain types and methods. Added Dictionaries.jl
end

### Methods
_length(d::D) where D <: DiscreteDomain = length(d.points)
<<<<<<< HEAD
<<<<<<< HEAD
_get(d::IndicesDomain, index::Int) = d.points[index]
=======
_get(d::IndexesDomain, index::Int) = d.points[index]
>>>>>>> Added domain structures and methods
=======
_get(d::IndicesDomain, index::Int) = d.points[index]
>>>>>>> Test for domain types and methods. Added Dictionaries.jl
_draw(d::D) where D <: DiscreteDomain = rand(d.points)
∈(value::T, d::D) where {T <: Real,D <: DiscreteDomain} = value ∈ d.points
_delete!(d::SetDomain{T}, value::T) where {T <: Real} = pop!(d.points, value)

# TODO: implement delete! for ContinuousDomain
<<<<<<< HEAD
<<<<<<< HEAD
function _delete!(d::IndicesDomain{T}, value::T) where T <: Real
    index = get(d.inds, value, 0)
    if index > 0
        deleteat!(d.points, index)
        delete!(d.inds, value)
        map(((k,v),) -> v < index ? v : v - 1, pairs(d.inds))
=======
function _delete!(d::IndexesDomain{T}, value::T) where T <: Real
    index = get(d.indexes, value, 0)
    if index > 0
        deleteat!(d.points, index)
        delete!(d.indexes, value)
        map(((k,v),) -> v < index ? v : v - 1, pairs(d.indexes))
>>>>>>> Added domain structures and methods
=======
function _delete!(d::IndicesDomain{T}, value::T) where T <: Real
    index = get(d.inds, value, 0)
    if index > 0
        deleteat!(d.points, index)
        delete!(d.inds, value)
        map(((k,v),) -> v < index ? v : v - 1, pairs(d.inds))
>>>>>>> Test for domain types and methods. Added Dictionaries.jl
    end
end

function _add!(d::SetDomain{T}, value::T) where {T <: Real}
    if !(value ∈ d)
        push!(d.points, value)
    end
end

<<<<<<< HEAD
<<<<<<< HEAD
function _add!(d::IndicesDomain{T}, value::T) where {T <: Real}
    if !(value ∈ d)
        push!(d.points, value)
        insert!(d.inds, value, length(d.points))
    end
end

_domain(::Val{:set}, values::Vector) = SetDomain(values)
_domain(::Val{:indices}, values::Vector) = IndicesDomain(values)

"""
    domain(values::Vector; domain = :set)
Discrete domain constructor.
The `type` keyword can be set to `:set` (default) or `:indices`.
"""
domain(values::Vector{T}; type = :set) where T <: Number = _domain(Val(type), values)
=======
function _add!(d::IndexesDomain{T}, value::T) where {T <: Real}
=======
function _add!(d::IndicesDomain{T}, value::T) where {T <: Real}
>>>>>>> Test for domain types and methods. Added Dictionaries.jl
    if !(value ∈ d)
        push!(d.points, value)
        insert!(d.inds, value, length(d.points))
    end
end
<<<<<<< HEAD
>>>>>>> Added domain structures and methods
=======

_domain(::Val{:set}, values::Vector) = SetDomain(values)
_domain(::Val{:indices}, values::Vector) = IndicesDomain(values)
domain(values::Vector{T}; domain = :set) where T <: Number = _domain(Val(domain), values)
>>>>>>> Test for domain types and methods. Added Dictionaries.jl
