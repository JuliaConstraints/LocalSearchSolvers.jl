struct Variable{D <: AbstractDomain}
    name::String
    domain::D
    constraints::Indices{Int}
end

# Methods: lazy forwarding from domain.jl
@forward Variable.domain _length, _get, _draw, _delete!, _add!

# Constraint related Methods
function _add_to_constraint!(x::Variable, id::Int)
    insert!(x.constraints, id)
end

function _delete_from_constraint!(x::Variable, id::Int)
    delete!(x.constraints, id)
end

_constriction(x::Variable) = length(x.constraints)
∈(x::Variable, constraint::Int) = constraint ∈ x.constraints
∈(value::T, x::Variable) where {T <: Real} = value ∈ x.domain

"""
    variable(values::Vector{T}, name::String; domain = :set) where T <: Number
    variable(domain::D, name::String) where D <: AbstractDomain
Construct a variable with discrete domain. See the `domain` method.
"""
function variable(domain::D, name::String) where D <: AbstractDomain
    return Variable(name, domain, Indices{Int}())
end
function variable(values::Vector{T}, name::String; dom = :set) where T <: Number
    variable(domain(values; type = dom), name)
end
