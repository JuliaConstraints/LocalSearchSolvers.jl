"""
    Constraint{F <: Function}

Structure to store an error function and the variables it constrains.
"""
struct Constraint{F <: Function} <: FunctionContainer
    f::F
    vars::Vector{Int}
end

function Constraint(F, c::Constraint{F2}) where {F2 <: Function}
    return Constraint{F}(c.f, c.vars)
end

"""
    _get_vars(c::Constraint)

Returns the variables constrained by `c`.
"""
_get_vars(c::Constraint) = c.vars

"""
    _add!(c::Constraint, x)

Add the variable of indice `x` to `c`.
"""
_add!(c::Constraint, x) = push!(c.vars, x)

"""
    _delete!(c::Constraint, x::Int)

Delete `x` from `c`.
"""
_delete!(c::Constraint, x) = deleteat!(c.vars, findfirst(y -> y == x, c.vars))

"""
    _length(c::Constraint)

Return the number of constrained variables by `c`.
"""
_length(c::Constraint) = length(c.vars)

"""
    var::Int ∈ c::Constraint
"""
∈(var::Int, c::Constraint) = var ∈ c.vars

"""
    constraint(f, vars)

DOCSTRING
"""
function constraint(f, vars)
    # TODO: fix in clean way the x86 compatibility
    return Constraint(f, collect(Int == Int32 ? map(Int,vars) : vars))
end
