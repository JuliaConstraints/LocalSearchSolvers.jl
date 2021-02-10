"""
    MOIError{F <: Function} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `f::F`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOIError(f, dim = 0) = begin
        #= none:5 =#
        new{typeof(f)}(f, dim)
    end`: DESCRIPTION
"""
struct MOIError{F <: Function} <: MOI.AbstractVectorSet
    f::F
    dimension::Int

    MOIError(f, dim = 0) = new{typeof(f)}(f, dim)
end

"""
    MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIError}) = begin

DOCSTRING

# Arguments:
- ``: DESCRIPTION
- ``: DESCRIPTION
- ``: DESCRIPTION
"""
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIError}) = true

"""
    MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIError)

DOCSTRING

# Arguments:
- `optimizer`: DESCRIPTION
- `vars`: DESCRIPTION
- `set`: DESCRIPTION
"""
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIError)
    cidx = constraint!(optimizer, set.f, map(x -> x.value, vars.variables))
    return CI{SVF, MOIError}(cidx)
end

"""
    Base.copy(set::MOIError) = begin

DOCSTRING
"""
Base.copy(set::MOIError) = MOIError(copy(set.f), copy(set.dimension))

"""
    Error{F <: Function} <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct Error{F <: Function} <: JuMP.AbstractVectorSet
    f::F
end

# @autodoc
JuMP.moi_set(set::Error{F}, dim::Int) where {F <: Function} = MOIError(set.f, dim)

"""
    MOIPredicate{F <: Function} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `f::F`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOIPredicate(f, dim = 0) = begin
        #= none:5 =#
        new{typeof(f)}(f, dim)
    end`: DESCRIPTION
"""
struct MOIPredicate{F <: Function} <: MOI.AbstractVectorSet
    f::F
    dimension::Int

    MOIPredicate(f, dim = 0) = new{typeof(f)}(f, dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIPredicate}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIPredicate)
    err = x -> convert(Float64, !set.f(x))
    cidx = constraint!(optimizer, err, map(x -> x.value, vars.variables))
    return CI{SVF, MOIPredicate}(cidx)
end

Base.copy(set::MOIPredicate) = MOIEMOIPredicaterror(copy(set.f), copy(set.dimension))

"""
    Predicate{F <: Function} <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct Predicate{F <: Function} <: JuMP.AbstractVectorSet
    f::F
end
JuMP.moi_set(set::Predicate, dim::Int) = MOIPredicate(set.f, dim)

"""
    MOIAllDifferent <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAllDifferent <: MOI.AbstractVectorSet
    dimension::Int

    MOIAllDifferent(dim = 0) = new(dim)
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

"""
    AllDifferent <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct AllDifferent <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AllDifferent, dim::Int) = MOIAllDifferent(dim)

"""
    MOIAllEqual <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAllEqual <: MOI.AbstractVectorSet
    dimension::Int

    MOIAllEqual(dim = 0) = new(dim)
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

Base.copy(set::MOIAllEqual) = MOIAllEqual(copy(set.dimension))

"""
    AllEqual <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct AllEqual <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AllEqual, dim::Int) = MOIAllEqual(dim)

"""
    MOIEq <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIEq <: MOI.AbstractVectorSet
    dimension::Int

    MOIEq(dim = 0) = new(dim)
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

Base.copy(set::MOIEq) = MOIEq(copy(set.dimension))

"""
    Eq <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct Eq <: JuMP.AbstractVectorSet end
JuMP.moi_set(::Eq, dim::Int) = MOIEq(dim)

"""
    MOIAlwaysTrue <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAlwaysTrue <: MOI.AbstractVectorSet
    dimension::Int

    MOIAlwaysTrue(dim = 0) = new(dim)
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

Base.copy(set::MOIAlwaysTrue) = MOIAlwaysTrue(copy(set.dimension))

"""
    AlwaysTrue <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct AlwaysTrue <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AlwaysTrue, dim::Int) = MOIAlwaysTrue(dim)

"""
    MOIOrdered <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIOrdered <: MOI.AbstractVectorSet
    dimension::Int

    MOIOrdered(dim = 0) = new(dim)
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

Base.copy(set::MOIOrdered) = MOIOrdered(copy(set.dimension))

"""
    Ordered <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct Ordered <: JuMP.AbstractVectorSet end
JuMP.moi_set(::Ordered, dim::Int) = MOIOrdered(dim)


"""
    MOIDistDifferent <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIDistDifferent <: MOI.AbstractVectorSet
    dimension::Int

    MOIDistDifferent(dim = 4) = new(dim)
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

"""
    DistDifferent <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct DistDifferent <: JuMP.AbstractVectorSet end
JuMP.moi_set(::DistDifferent, dim::Int) = MOIDistDifferent(dim)

"""
    MOIAllEqualParam{T <: Number} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `param::T`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOIAllEqualParam(param, dim = 0) = begin
        #= none:5 =#
        new{typeof(param)}(param, dim)
    end`: DESCRIPTION
"""
struct MOIAllEqualParam{T <: Number} <: MOI.AbstractVectorSet
    param::T
    dimension::Int

    MOIAllEqualParam(param, dim = 0) = new{typeof(param)}(param, dim)
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

Base.copy(set::MOIAllEqualParam) = MOIAllEqualParam(copy(set.param),
copy(set.dimension))

"""
    AllEqualParam{T <: Number} <: JuMP.AbstractVectorSet

DOCSTRING
"""
struct AllEqualParam{T <: Number} <: JuMP.AbstractVectorSet
    param::T
end
JuMP.moi_set(set::AllEqualParam, dim::Int) = MOIAllEqualParam(dim, set.param)
