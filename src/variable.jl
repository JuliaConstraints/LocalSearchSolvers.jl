"""
    Variable{D <: AbstractDomain}
A structure containing the necessary information for a solver's variables: `name`, `domain`, and `constraints` it belongs.
```
struct Variable{D <: AbstractDomain}
    domain::D
    constraints::Indices{Int}
end
```
"""
mutable struct Variable{D <: AbstractDomain}
    domain::D
    constraints::Indices{Int}
end

function Variable(D, x::Variable{D2}) where {D2 <: AbstractDomain}
    return Variable{D}(x.domain, x.constraints)
end

# Methods: lazy forwarding from ConstraintDomains.domain.jl
@forward Variable.domain Base.length, Base.rand, Base.delete!, Base.isempty
# @forward Variable.domain get_domain, domain_size

add!(x::Variable, value) = ConstraintDomains.add!(x.domain, value)
get_domain(x::Variable) = ConstraintDomains.get_domain(x.domain)
domain_size(x::Variable) = ConstraintDomains.domain_size(x.domain)

"""
    _get_constraints(x::Variable)
Access the list of `constraints` of `x`.
"""
_get_constraints(x::Variable) = x.constraints

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
    x::Variable ∈ constraint
    value ∈ x::Variable
Check if a variable `x` is restricted by a `constraint::Int`, or if a `value` belongs to the domain of `x`.
"""
Base.in(x::Variable, constraint) = constraint ∈ x.constraints
Base.in(value, x::Variable) = value ∈ x.domain

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
variable() = Variable(domain(), Indices{Int}())
variable(domain::D) where {D <: AbstractDomain} = Variable(domain, Indices{Int}())
variable(vals) = isempty(vals) ? variable() : variable(domain(vals))
