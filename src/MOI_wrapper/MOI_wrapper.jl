
# MOI functions
const SVF = MOI.SingleVariable
const VOV = MOI.VectorOfVariables
const OF = MOI.ObjectiveFunction

# MOI indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# MOI types
const VAR_TYPES = Union{MOI.ZeroOne, MOI.Integer}

# support for @variable(m, x, Set)

"""
    JuMP.build_variable(::Function, info::JuMP.VariableInfo, set::T) where T <: MOI.AbstractScalarSet

DOCSTRING

# Arguments:
- ``: DESCRIPTION
- `info`: DESCRIPTION
- `set`: DESCRIPTION
"""
function JuMP.build_variable(
    ::Function,
    info::JuMP.VariableInfo,
    set::T,
) where {T<:MOI.AbstractScalarSet}
    return JuMP.VariableConstrainedOnCreation(JuMP.ScalarVariable(info), set)
end

"""
    Optimizer <: MOI.AbstractOptimizer

DOCSTRING

# Arguments:
- `solver::Solver`: DESCRIPTION
- `status::MOI.TerminationStatusCode`: DESCRIPTION
- `options::Options`: DESCRIPTION
"""
mutable struct Optimizer <: MOI.AbstractOptimizer
    solver::Solver
    status::MOI.TerminationStatusCode
    options::Options
end

"""
    Optimizer(model = Model(); options = Options())

DOCSTRING
"""
function Optimizer(model = model(); options = Options())
    Optimizer(Solver(model), MOI.OPTIMIZE_NOT_CALLED, options)
end

# forward functions from Solver
@forward Optimizer.solver variable!, _set_domain!, constraint!, solution, domain_size
@forward Optimizer.solver max_domains_size, objective!, empty!, _inc_cons!, _max_cons
@forward Optimizer.solver _best_bound, _best, is_sat, _value, _solution

"""
    MOI.get(::Optimizer, ::MOI.SolverName) = begin

DOCSTRING
"""
MOI.get(::Optimizer, ::MOI.SolverName) = "LocalSearchSolvers"

"""
    MOI.set(::Optimizer, ::MOI.Silent, bool = true) = begin

DOCSTRING

# Arguments:
- ``: DESCRIPTION
- ``: DESCRIPTION
- `bool`: DESCRIPTION
"""
MOI.set(::Optimizer, ::MOI.Silent, bool = true) = @debug "TODO: Silent"

"""
    MOI.is_empty(model::Optimizer) = begin

DOCSTRING
"""
MOI.is_empty(model::Optimizer) = _is_empty(model.solver)

"""
Copy constructor for the optimizer
"""
MOIU.supports_default_copy_to(::Optimizer, copy_names::Bool) = !copy_names
function MOI.copy_to(model::Optimizer, src::MOI.ModelLike; kws...)
    return MOIU.automatic_copy_to(model, src; kws...)
end

"""
    set_status!(optimizer::Optimizer, status::Symbol)

DOCSTRING
"""
function set_status!(optimizer::Optimizer, status::Symbol)
    if status == :Solved
        optimizer.status = MOI.OPTIMAL
    elseif status == :Infeasible
        optimizer.status = MOI.INFEASIBLE
    elseif status == :LocalOptimum
        optimizer.status = MOI.TIME_LIMIT
    else
        optimizer.status = MOI.OTHER_LIMIT
    end
end

"""
    MOI.optimize!(model::Optimizer)
"""
function MOI.optimize!(optimizer::Optimizer)
    set_status!(optimizer, solve!(optimizer.solver))
end

"""
    DiscreteSet(values)
"""
struct DiscreteSet{T <: Number} <: MOI.AbstractScalarSet
    values::Vector{T}
end
DiscreteSet(values) = DiscreteSet(collect(values))
DiscreteSet(values::T...) where {T<:Number} = DiscreteSet(collect(values))

"""
    Base.copy(set::DiscreteSet) = begin

DOCSTRING
"""
Base.copy(set::DiscreteSet) = DiscreteSet(copy(set.values))

"""
    MOI.empty!(opt) = begin

DOCSTRING
"""
MOI.empty!(opt) = empty!(opt)
