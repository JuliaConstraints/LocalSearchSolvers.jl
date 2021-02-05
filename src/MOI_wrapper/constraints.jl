struct Error{F <: Function} <: MOI.AbstractVectorSet
    f::F
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{Error}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::Error)
    cidx = constraint!(optimizer, set.f, map(x -> x.value, vars.variables))
    return CI{SVF, Error}(cidx)
end

struct Predicate{F <: Function} <: MOI.AbstractVectorSet
    f::F
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{Predicate}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::Predicate)
    return MOI.add_constraint(optimizer, vars, Error(x -> convert(Float64, !set.f(x))))
end

struct AllDifferent <: MOI.AbstractVectorSet
    dimension::Int64
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{AllDifferent}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::AllDifferent)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:all_different])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, AllDifferent}(cidx)
end
Base.copy(set::AllDifferent) = AllDifferent(copy(set.dimension))

struct AllEqual <: MOI.AbstractVectorSet end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{AllEqual}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::AllEqual)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:all_equal])(x; param=param, dom_size=dom_size
    )
    return MOI.add_constraint(optimizer, vars, Error(e))
end

struct Eq <: MOI.AbstractVectorSet end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{Eq}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::Eq)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:eq])(x; param=param, dom_size=dom_size
    )
    return MOI.add_constraint(optimizer, vars, Error(e))
end

struct AlwaysTrue <: MOI.AbstractVectorSet end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{AlwaysTrue}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::AlwaysTrue)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:always_true])(x; param=param, dom_size=dom_size
    )
    return MOI.add_constraint(optimizer, vars, Error(e))
end

struct Ordered <: MOI.AbstractVectorSet end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{Ordered}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::Ordered)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:ordered])(x; param=param, dom_size=dom_size
    )
    return MOI.add_constraint(optimizer, vars, Error(e))
end

struct DistDifferent <: MOI.AbstractVectorSet end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{DistDifferent}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::DistDifferent)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:dist_different])(x; param=param, dom_size=dom_size
    )
    return MOI.add_constraint(optimizer, vars, Error(e))
end

struct AllEqualParam{T <: Number} <: MOI.AbstractVectorSet
    param::T
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{AllEqualParam}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::AllEqualParam)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=set.param, dom_size=max_dom_size) -> error_f(
        usual_constraints[:all_equal_param])(x; param=param, dom_size=dom_size
    )
    return MOI.add_constraint(optimizer, vars, Error(e))
end
