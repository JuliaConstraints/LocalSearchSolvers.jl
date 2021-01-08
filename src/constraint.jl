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

# Constructors

"""
    constraint(f::F, inds::Vector{Int}, values::Vector{T}) where {F <: Function,T <: Number}
    constraint(f::F, inds::Vector{Int}, vars::Dictionary{Int,Variable}) where F <: Function

Test the validity of `f` over a set of `values` or draw them from a set of variables `vars`.
Return a constraint if the test is succesful, otherwise raise an error.
"""
function constraint(f::F, inds::AbstractVector{Int}, values::AbstractVector{T}
) where {T <: Number,F <: Function}
    Constraint(f, inds, values)
end

function constraint(f::F, inds::AbstractVector{Int}, vars::Dictionary{Int,Variable}
) where {F <: Function}
    Constraint(f, inds, vars)
end

# Methods
_get_vars(c::Constraint) = c.vars
_add!(c::Constraint, x::Int) = push!(c.vars, x)
_delete!(c::Constraint, x::Int) = deleteat!(c.vars, findfirst(y -> y == x, c.vars))
_length(c::Constraint) = length(c.vars)
∈(var::Int, c::Constraint) = var ∈ c.vars
