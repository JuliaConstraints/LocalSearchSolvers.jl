struct Constraint{F <: Function}
    f::F
    vars::Vector{Int}

    function Constraint{F}(f::F, vars::Vector{Int}, values::Vector{T}
    ) where {F <: Function,T <: Real}
        aux_values = [values[id] for id in vars]
        arg_err = ArgumentError("Function has no method with signature $(typeof.(values))")
        applicable(f, aux_values...) || throw(arg_err)
        return new(f, vars)
    end

    function Constraint{F}(f::F, vars_id::Vector{Int}, vars_dict::Dictionary{Int,Variable}
    ) where {F <: Function}
        values = [_draw(vars_dict[id]) for id in vars_id]
        arg_err = ArgumentError("Function has no method with signature $(typeof.(values))")
        applicable(f, values...) || throw(arg_err)
        return new(f, vars_id)
    end
end

function Constraint(f::F, vars::Vector{Int}, values::Vector{T}
) where {F <: Function,T <: Real}
    Constraint{F}(f, vars, values)
end

function Constraint(f::F, vars_id::Vector{Int}, vars_dict::Dictionary{Int,Variable}
) where {F <: Function}
    Constraint{F}(f, vars_id, vars_dict)
end

# methods

_add!(c::Constraint, x::Int) = push!(c.vars, x)
_delete!(c::Constraint, x::Int) = deleteat!(c.vars, findfirst(y -> y == x, c.vars))
_length(c::Constraint) = length(c.vars)
∈(var::Int, c::Constraint) = var ∈ c.vars
