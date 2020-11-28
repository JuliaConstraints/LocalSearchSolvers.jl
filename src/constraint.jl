struct Constraint{F <: Function}
    f::F
    vars::Vector{Int}

    function Constraint{F}(f::F, inds::Vector{Int}, values::Vector{T}
    ) where {F <: Function,T <: Real}
        aux_values = [values[id] for id in inds]
        arg_err = ArgumentError("Function has no method with signature $(typeof.(values))")
        applicable(f, aux_values...) || throw(arg_err)
        return new(f, inds)
    end

    function Constraint{F}(f::F, inds::Vector{Int}, vars::Dictionary{Int,Variable}
    ) where {F <: Function}
        values = [_draw(vars[id]) for id in inds]
        arg_err = ArgumentError("Function has no method with signature $(typeof.(values))")
        applicable(f, values...) || throw(arg_err)
        return new(f, inds)
    end
end

# Constructors

"""
    constraint(f::F, inds::Vector{Int}, values::Vector{T}) where {F <: Function,T <: Real}
    constraint(f::F, inds::Vector{Int}, vars::Dictionary{Int,Variable}) where F <: Function

Test the validity of `f` over a set of `values` or draw them from a set of variables `vars`.
Return a constraint if the test is succesful, otherwise raise an error.
"""
function constraint(f::F, inds::Vector{Int}, values::Vector{T}
) where {F <: Function,T <: Real}
    Constraint{F}(f, inds, values)
end

function constraint(f::F, inds::Vector{Int}, vars::Dictionary{Int,Variable}
) where {F <: Function}
    Constraint{F}(f, inds, vars)
end

# Methods

_get_vars(c::Constraint) = c.vars

_add!(c::Constraint, x::Int) = push!(c.vars, x)
_delete!(c::Constraint, x::Int) = deleteat!(c.vars, findfirst(y -> y == x, c.vars))
_length(c::Constraint) = length(c.vars)
∈(var::Int, c::Constraint) = var ∈ c.vars

## temp definition of all_different
# TODO: make it annon func
function _insert_or_inc(d::Dictionary{Int, Int}, ind::Int)
    set!(d, ind, isassigned(d, ind) ? d[ind] + 1 : 1)
end

