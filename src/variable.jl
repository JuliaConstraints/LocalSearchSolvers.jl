struct Variable{D <: AbstractDomain}
    name::String
    domain::D
    constraints::Indices{Int}
end

# Methods: lazy forwarding from domain.jl
@forward Variable.domain _length, _get, _draw, _delete!, _add!, _get_domain

# Accessors
_get_constraints(x::Variable) = x.constraints
_get_name(x::Variable) = x.name

# Constraint related Methods
_add_to_constraint!(x::Variable, id::Int) = set!(_get_constraints(x), id)
_delete_from_constraint!(x::Variable, id::Int) = delete!(x.constraints, id)
_constriction(x::Variable) = length(x.constraints)
∈(x::Variable, constraint::Int) = constraint ∈ x.constraints
∈(value::Number, x::Variable) = value ∈ x.domain

"""
    variable(values::AbstractVector{T}, name::AbstractString; domain = :set) where T <: Number
    variable(domain::AbstractDomain, name::AbstractString) where D <: AbstractDomain
Construct a variable with discrete domain. See the `domain` method for other options.

```julia
d = domain([1,2,3,4], types = :indices)
x1 = variable(d, "x1")
x2 = variable([-89,56,28], "x2", domain = :indices)
```
"""
function variable(domain::AbstractDomain, name::AbstractString)
    Variable(name, domain, Indices{Int}())
end

function variable(values::AbstractVector{T}, name::AbstractString; dom=:set) where {T <: Number}
    variable(domain(values; type=dom), name)
end
