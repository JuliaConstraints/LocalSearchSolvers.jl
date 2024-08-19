"""
    struct Constraint{F <: Function} <: FunctionContainer

Structure to store an error function and the variables it constrains.

# Fields
- `f::F`: The constraint function
- `vars::Vector{Int}`: Indices of variables constrained by this constraint
"""
struct Constraint{F <: Function} <: FunctionContainer
    f::F
    vars::Vector{Int}
end

"""
    Constraint(F, c::Constraint{F2}) where {F2 <: Function}

Construct a new Constraint with a potentially different function type, preserving the variables of the input constraint.

# Arguments
- `F`: The desired function type for the new constraint
- `c::Constraint{F2}`: The original constraint to be converted
"""
function Constraint(F, c::Constraint{F2}) where {F2 <: Function}
    return Constraint{F}(c.f, c.vars)
end

"""
    get_vars(c::Constraint)

Returns the variables constrained by `c`.
"""
get_vars(c::Constraint) = c.vars

"""
    add!(c::Constraint, x)

Add the variable of index `x` to `c`.
"""
add!(c::Constraint, x::Int) = push!(c.vars, x)

"""
    delete!(c::Constraint, x)

Delete variable with index `x` from `c`.
"""
Base.delete!(c::Constraint, x) = deleteat!(c.vars, findfirst(y -> y == x, c.vars))

"""
    length(c::Constraint)

Return the number of variables constrained by `c`.
"""
Base.length(c::Constraint) = length(c.vars)

"""
    var::Int ∈ c::Constraint

Check if a variable with index `var` is constrained by `c`.
"""
Base.in(var::Int, c::Constraint) = var ∈ c.vars

"""
    constraint(f, vars)

Construct a new Constraint.

# Arguments
- `f`: The constraint function
- `vars`: A collection of variable indices

# Notes
- If `f` doesn't accept a single argument with a keyword argument `X`, it's wrapped to do so.
- Variable indices are converted to `Int` if necessary.
"""
function constraint(f, vars)
    b1 = hasmethod(f, NTuple{1, Any}, (:X,))
    b2 = hasmethod(f, NTuple{1, Any}, (:do_not_use_this_kwarg_name,))
    g = f
    if !b1 || b2
        g = (x; X = nothing) -> f(x)
    end
    return Constraint(g, collect(Int == Int32 ? map(Int, vars) : vars))
end

@testitem "Constraint" tags=[:constraint, :model] begin
    import LocalSearchSolvers as LS

    c = constraint(sum, [1, 2, 3])
    @test length(c) == 3
    @test 1 ∈ c
    @test 2 ∈ c
    @test 3 ∈ c
    @info c typeof(c)
    add!(c, 4)
    @test 4 ∈ c
    @test LS.get_vars(c) == [1, 2, 3, 4]
    delete!(c, 4)
    @test 4 ∉ c
end
