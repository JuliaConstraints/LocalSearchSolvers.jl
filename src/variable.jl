"""
    Variable{D <: AbstractDomain}
A structure containing the necessary information for a solver's variables: `name`, `domain`, and `constraints` it belongs.
```
struct Variable{D <: AbstractDomain}
    name::String
    domain::D
    constraints::Indices{Int}
end
```
"""
struct Variable{D <: AbstractDomain}
    name::String
    domain::D
    constraints::Indices{Int}
end

# Methods: lazy forwarding from ConstraintDomains.domain.jl
@forward Variable.domain _length, _get, _draw, _delete!, _add!, _get_domain

"""
    _get_constraints(x::Variable)
Access the list of `constraints` of `x`.
"""
_get_constraints(x::Variable) = x.constraints

"""
    _get_name(x::Variable)
Access the `name` of `x`.
"""
_get_name(x::Variable) = x.name

"""
    _add_to_constraint!(x::Variable, id)
Add a constraint `id` to the list of contraints of `x`.
"""
_add_to_constraint!(x::Variable, id) = set!(_get_constraints(x), id)

"""
    _delete_from_constraint!(x::Variable, id)
Delete a constraint `id` from the list of contraints of `x`.
"""
_delete_from_constraint!(x::Variable, id) = delete!(x.constraints, id)

"""
    _constriction(x::Variable)
Return the `cosntriction` of `x`, i.e. the number of constraints restricting `x`.
"""
_constriction(x::Variable) = length(x.constraints)

"""
    ∈(x::Variable, constraint)
    ∈(value, x::Variable)
Check if a variable `x` is restricted by a `constraint::Int`, or if a `value` belongs to the domain of `x`.
"""
∈(x::Variable, constraint) = constraint ∈ x.constraints
∈(value, x::Variable) = value ∈ x.domain

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
