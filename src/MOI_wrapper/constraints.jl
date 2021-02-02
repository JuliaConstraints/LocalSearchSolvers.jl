struct Predicate{F <: Function} <: MOI.AbstractVectorSet
    f::F
end

struct Error{F <: Function} <: MOI.AbstractVectorSet
    f::F
end

MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{Predicate}) = true

function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::Predicate)
    return constraint!(optimizer, set.f, map(x -> x.variable.value, vars))
end
