"""
    Constraint{F <: Function}

Structure to store an error function and the variables it constrains.
"""
struct Constraint{F <: Function} <: FunctionContainer
    f::F
    vars::Vector{Int}
    positions::Dict{Int, Int}
end

struct WorkspaceAdapter{F <: Function} <: Function
    evaluator::F
end

(adapter::WorkspaceAdapter)(values; X = nothing) = adapter.evaluator(values)
Constraints.supports_incremental(adapter::WorkspaceAdapter) =
    supports_incremental(adapter.evaluator)

function Constraints.initialize_invariant(
        adapter::WorkspaceAdapter, values; X = nothing, parameters...)
    return initialize_invariant(adapter.evaluator, values; parameters...)
end

function Constraint(F, c::Constraint{F2}) where {F2 <: Function}
    return Constraint{F}(c.f, c.vars, c.positions)
end

function Constraint(f::F, vars::Vector{Int}) where {F <: Function}
    positions = Dict(variable => position for (position, variable) in pairs(vars))
    return Constraint{F}(f, vars, positions)
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
function _add!(c::Constraint, x)
    push!(c.vars, x)
    c.positions[x] = length(c.vars)
    return c
end

"""
    _delete!(c::Constraint, x::Int)

Delete `x` from `c`.
"""
function _delete!(c::Constraint, x)
    position = findfirst(==(x), c.vars)
    isnothing(position) && return c
    deleteat!(c.vars, position)
    delete!(c.positions, x)
    for index in position:length(c.vars)
        c.positions[c.vars[index]] = index
    end
    return c
end

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
        g = WorkspaceAdapter(f)
    end
    return Constraint(g, collect(Int == Int32 ? map(Int, vars) : vars))
end
