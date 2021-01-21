"""
    Constraint{F <: Function}

Structure to store an error function and the variables it constrains.
"""
struct Constraint{F <: Function}
    f::F
    vars::Vector{Int}

    function Constraint(F, c::Constraint{F2}) where {F2 <: Function}
        return new{F}(c.f, c.vars)
    end
    function Constraint(f::F, inds::AbstractVector{Int}, values::AbstractVector{T}
        ) where {T <: Number,F <: Function}
        aux_values = map(id -> values[id], inds)
        arg_err = ArgumentError("Function has no method with signature $(typeof.(values))")
        applicable(f, aux_values) || throw(arg_err)
        # @info typeof(aux_values)
        return new{F}(f, inds)
    end

    function Constraint(
            f::F, inds::AbstractVector{Int}, vars::Dictionary{Int,Variable}
        ) where {F <: Function}
        values = map(id ->_draw(vars[id]), inds)
        arg_err = ArgumentError("Function has no method with signature $(typeof.(values))")
        applicable(f, values) || throw(arg_err)
        # @info typeof(values)
        return new{F}(f, inds)
    end
end

"""
    constraint(f, inds, vars_or_values)

Test the validity of `f` over a set of values or draw them from a set of variables vars.
Return a constraint if the test is succesful, otherwise raise an error.

# Arguments:
- `f`: an error function
- `inds`: indices of the constrained variables
- `vars_or_values`: either a Dictionary of variables or a collection of values
"""
constraint(f, inds, vars_or_values) = Constraint(f, inds, vars_or_values)

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
