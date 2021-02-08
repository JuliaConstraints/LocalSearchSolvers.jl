
# MOI functions
const SVF = MOI.SingleVariable
const VOV = MOI.VectorOfVariables

# MOI indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# MOI types
const VAR_TYPES = Union{MOI.ZeroOne, MOI.Integer}

# support for @variable(m, x, Set)
function JuMP.build_variable(
    ::Function,
    info::JuMP.VariableInfo,
    set::T,
) where {T<:MOI.AbstractScalarSet}
    return JuMP.VariableConstrainedOnCreation(JuMP.ScalarVariable(info), set)
end

mutable struct Optimizer <: MOI.AbstractOptimizer
    solver::Solver
    status::MOI.TerminationStatusCode
    options::Options
end

function Optimizer(model = Model(); options = Options())
    Optimizer(Solver(model), MOI.OPTIMIZE_NOT_CALLED, options)
end

# forward functions from Solver
@forward Optimizer.solver variable!, _set_domain!, constraint!, solution, domain_size
@forward Optimizer.solver max_domains_size, objective!, empty!, _inc_cons!, _max_cons
@forward Optimizer.solver _best_bound, _best, is_sat

MOI.get(::Optimizer, ::MOI.SolverName) = "LocalSearchSolvers"

MOI.set(::Optimizer, ::MOI.Silent, bool = true) = @warn "TODO: Silent"

MOI.is_empty(model::Optimizer) = _is_empty(model.solver)

"""
Copy constructor for the optimizer
"""
MOIU.supports_default_copy_to(::Optimizer, copy_names::Bool) = !copy_names
function MOI.copy_to(model::Optimizer, src::MOI.ModelLike; kws...)
    return MOIU.automatic_copy_to(model, src; kws...)
end

"""
    MOI.optimize!(model::Optimizer)
"""
MOI.optimize!(model::Optimizer) = solve!(model.solver)

"""
    DiscreteSet(values)
"""
struct DiscreteSet{T <: Number} <: MOI.AbstractScalarSet
    values::Vector{T}
end
DiscreteSet(values) = DiscreteSet(collect(values))
DiscreteSet(values::T...) where {T<:Number} = DiscreteSet(collect(values))

Base.copy(set::DiscreteSet) = DiscreteSet(copy(set.values))

"""
    ScalarFunction(objective)
"""
struct ScalarFunction{F <: Function} <: MOI.AbstractScalarFunction
    f::F
end

Base.copy(func::ScalarFunction) = ScalarFunction(func.f)

MOI.empty!(opt) = empty!(opt)
