struct MOIError{F <: Function} <: MOI.AbstractVectorSet
    f::F
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIError}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIError)
    cidx = constraint!(optimizer, set.f, map(x -> x.value, vars.variables))
    return CI{SVF, MOIError}(cidx)
end

struct Error{F <: Function} <: JuMP.AbstractVectorSet
    f::F
end
JuMP.moi_set(::Error, dim::Int, func) = MOIError(dim)

struct MOIPredicate{F <: Function} <: MOI.AbstractVectorSet
    f::F
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIPredicate}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIPredicate)
    err = x -> convert(Float64, !set.f(x))
    cidx = constraint!(optimizer, err, map(x -> x.value, vars.variables))
    return CI{SVF, MOIPredicate}(cidx)
end

struct Predicate{F <: Function} <: JuMP.AbstractVectorSet
    f::F
end
JuMP.moi_set(::Predicate, dim::Int, func) = MOIPredicate(dim)

struct MOIAllDifferent <: MOI.AbstractVectorSet
    dimension::Int
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAllDifferent}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIAllDifferent)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:all_different])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAllDifferent}(cidx)
end
Base.copy(set::MOIAllDifferent) = MOIAllDifferent(copy(set.dimension))

struct AllDifferent <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AllDifferent, dim::Int) = MOIAllDifferent(dim)

struct MOIAllEqual <: MOI.AbstractVectorSet
    dimension::Int
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAllEqual}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIAllEqual)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:all_equal])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAllEqual}(cidx)
end

struct AllEqual <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AllEqual, dim::Int) = MOIAllEqual(dim)

struct MOIEq <: MOI.AbstractVectorSet
    dimension::Int
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIEq}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIEq)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:eq])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIEq}(cidx)
end

struct Eq <: JuMP.AbstractVectorSet end
JuMP.moi_set(::Eq, dim::Int) = MOIEq(dim)

struct MOIAlwaysTrue <: MOI.AbstractVectorSet
    dimension::Int
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAlwaysTrue}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIAlwaysTrue)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:always_true])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAlwaysTrue}(cidx)
end

struct AlwaysTrue <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AlwaysTrue, dim::Int) = MOIAlwaysTrue(dim)

struct MOIOrdered <: MOI.AbstractVectorSet
    dimension::Int
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIOrdered}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIOrdered)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:ordered])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIOrdered}(cidx)
end

struct Ordered <: JuMP.AbstractVectorSet end
JuMP.moi_set(::Ordered, dim::Int) = MOIOrdered(dim)


struct MOIDistDifferent <: MOI.AbstractVectorSet
    dimension::Int
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIDistDifferent}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIDistDifferent)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=nothing, dom_size=max_dom_size) -> error_f(
        usual_constraints[:dist_different])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIDistDifferent}(cidx)
end
Base.copy(set::MOIDistDifferent) = MOIDistDifferent(copy(set.dimension))

struct DistDifferent <: JuMP.AbstractVectorSet end
JuMP.moi_set(::DistDifferent, dim::Int) = MOIDistDifferent(dim)

struct MOIAllEqualParam{T <: Number} <: MOI.AbstractVectorSet
    dimension::Int
    param::T
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAllEqualParam}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIAllEqualParam)
    max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; param=set.param, dom_size=max_dom_size) -> error_f(
        usual_constraints[:all_equal_param])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAllEqualParam}(cidx)
end

struct AllEqualParam{T <: Number} <: JuMP.AbstractVectorSet
    param::T
end
JuMP.moi_set(::AllEqualParam, dim::Int, param) = MOIAllEqualParam(dim, param)
