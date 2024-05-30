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
Base.in(var::Int, c::Constraint) = var ∈ c.vars

"""
    constraint(f, vars)

DOCSTRING
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
