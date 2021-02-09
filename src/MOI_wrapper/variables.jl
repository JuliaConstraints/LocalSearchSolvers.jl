MOI.add_variable(model::Optimizer) = VI(variable!(model))
MOI.add_variables(model::Optimizer, n::Int) = [MOI.add_variable(model) for i in 1:n]

# MOI.supports_constraint(::Optimizer, ::Type{SVF}) = true

"""
Single variable bound constraints
"""
# function MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{MOI.LessThan{T}}
# ) where {T<:Real}
#     return true
# end

# function MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{MOI.GreaterThan{T}}
# ) where {T<:Real}
#     return true
# end

# function MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{MOI.EqualTo{T}}
# ) where {T<:Real}
#     return true
# end

# function MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{MOI.Interval{T}}
# ) where {T<:Real}
#     return true
# end

MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{DiscreteSet{T}}) where {T <: Number} = true

function MOI.add_constraint(optimizer::Optimizer, v::SVF, set::DiscreteSet{T}) where {T <: Number}
    vidx = MOI.index_value(v.variable)
    _set_domain!(optimizer, vidx, set.values)
    return CI{SVF, DiscreteSet{T}}(vidx)
end


"""
Binary/Integer variable support
"""
# MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{<:VAR_TYPES}) = true
