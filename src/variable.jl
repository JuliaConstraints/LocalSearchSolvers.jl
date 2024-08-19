"""
    mutable struct Variable{D <: AbstractDomain}

A mutable struct representing a variable in an optimization problem.

# Fields
- `domain::D`: The domain of the variable, which must be a subtype of `ConstraintDomains.AbstractDomain`.
- `constraints::Dictionaroes.Indices{Int}`: The indices of constraints associated with this variable.

# Type Parameters
- `D`: The specific type of the domain, which must be a subtype of `ConstraintDomains.AbstractDomain`.
"""
mutable struct Variable{D <: AbstractDomain}
    domain::D
    constraints::Indices{Int}
end

"""
    Variable(D, x::Variable{D2}) where {D2 <: AbstractDomain}

Construct a new `Variable` with a potentially different domain type, preserving the domain and constraints of the input variable.

This constructor allows for type conversion of the domain while maintaining the variable's properties.

# Arguments
- `D`: The desired domain type for the new variable.
- `x::Variable{D2}`: The original variable to be converted.

# Returns
A new `Variable` instance with the domain type `D`, containing the same domain and constraints as the input variable.

# Type Parameters
- `D2`: The domain type of the input variable.
"""
function Variable(D, x::Variable{D2}) where {D2 <: AbstractDomain}
    return Variable{D}(x.domain, x.constraints)
end

# SECTION - Methods: forwarding from ConstraintDomains.domain.jl
"""
    add!(x::Variable, value)

Add a value to the domain of the variable.

Forwards the call to ConstraintDomains.add! for the variable's domain.
"""
add!(x::Variable, value) = ConstraintDomains.add!(x.domain, value)

"""
    domain_size(x::Variable)

Get the size of the variable's domain.

Forwards the call to ConstraintDomains.domain_size for the variable's domain.
"""
domain_size(x::Variable) = ConstraintDomains.domain_size(x.domain)

"""
    get_domain(x::Variable)

Retrieve the domain of the variable.

Forwards the call to ConstraintDomains.get_domain for the variable's domain.
"""
get_domain(x::Variable) = ConstraintDomains.get_domain(x.domain)

"""
    Base.length(x::Variable)

Get the length of the variable's domain.

Delegates to the length method of the variable's domain.
"""
Base.length(x::Variable) = length(x.domain)

"""
    Base.rand(x::Variable)

Generate a random value from the variable's domain.

Delegates to the rand method of the variable's domain.
"""
Base.rand(x::Variable) = rand(x.domain)

"""
    Base.delete!(x::Variable, value)

Remove a value from the variable's domain.

Delegates to the delete! method of the variable's domain.
"""
Base.delete!(x::Variable, value) = delete!(x.domain, value)

"""
    Base.isempty(x::Variable)

Check if the variable's domain is empty.

Delegates to the isempty method of the variable's domain.
"""
Base.isempty(x::Variable) = isempty(x.domain)

# SECTION - Methods: Variable
"""
    get_constraints(x::Variable)

Access the list of constraints associated with the variable `x`.

Returns the `constraints` field of the variable, which is an `Indices{Int}` object.
"""
get_constraints(x::Variable) = x.constraints

"""
    add_to_constraint!(x::Variable, id)

Add a constraint `id` to the list of constraints associated with the variable `x`.

The constraint `id` is added to the `constraints` field of the variable using the `set!` function.
"""
add_to_constraint!(x::Variable, id) = set!(get_constraints(x), id)

"""
    delete_from_constraint!(x::Variable, id)

Remove a constraint `id` from the list of constraints associated with the variable `x`.

The constraint `id` is removed from the `constraints` field of the variable using the `delete!` function.
"""
delete_from_constraint!(x::Variable, id) = delete!(x.constraints, id)

"""
    constriction(x::Variable)

Calculate the constriction of the variable `x`.

Returns the number of constraints restricting the variable, which is the length of the `constraints` field.
"""
constriction(x::Variable) = length(x.constraints)

"""
    x::Variable ∈ constraint
    value ∈ x::Variable

Check if a variable `x` is restricted by a `constraint::Int`, or if a `value` belongs to the domain of `x`.

For `x::Variable ∈ constraint`, it checks if the constraint is in the variable's constraints list.
For `value ∈ x::Variable`, it checks if the value is in the variable's domain.
"""
Base.in(x::Variable, constraint) = constraint ∈ x.constraints
Base.in(value, x::Variable) = value ∈ x.domain

"""
    variable()
    variable(domain::D) where {D <: AbstractDomain}
    variable(vals)

Construct a variable with a specified domain.

# Methods
1. `variable()`: Creates a variable with a default empty domain.
2. `variable(domain::D) where {D <: AbstractDomain}`: Creates a variable with a given domain.
3. `variable(vals)`: Creates a variable from any iterable, or an empty variable if the iterable is empty.

# Returns
A `Variable` instance with the specified domain and an empty set of constraints (`Indices{Int}()`).

# Notes
- When called with no arguments, it creates a variable with a default empty domain.
- When called with a domain, it directly uses that domain to create the variable.
- When called with a collection of values, it creates a domain from those values unless the collection is empty, in which case it creates an empty variable.
"""
variable() = Variable(domain(), Indices{Int}())
variable(domain::D) where {D <: AbstractDomain} = Variable(domain, Indices{Int}())
variable(vals) = isempty(vals) ? variable() : variable(domain(vals))

@testitem "Variable" tags=[:variable, :model] begin
    import LocalSearchSolvers as LS
    import Dictionaries

    x_empty = LS.variable()
    @test isempty(x_empty) == true
    x_vals = LS.variable(1:3)
    @test LS.get_domain(x_vals) == 1:3

    x = variable([1, 2, 3, 4, 5])
    @test LS.get_domain(x) == Set([1, 2, 3, 4, 5])
    @test isempty(x) == false
    @test length(x) == 5
    @test rand(x) ∈ x
    @test 3 ∈ x
    @test 6 ∉ x
    add!(x, 6)
    @test 6 ∈ x
    LS.delete!(x, 6)
    @test 6 ∉ x
    @test LS.domain_size(x) == 4

    @test LS.get_constraints(x) == Dictionaries.Indices{Int}()
    @test LS.constriction(x) == 0
    LS.add_to_constraint!(x, 1)
    @test LS.get_constraints(x) == Dictionaries.Indices{Int}([1])
    @test LS.constriction(x) == 1
    LS.delete_from_constraint!(x, 1)
    @test LS.get_constraints(x) == Dictionaries.Indices{Int}()
    @test LS.constriction(x) == 0
end
