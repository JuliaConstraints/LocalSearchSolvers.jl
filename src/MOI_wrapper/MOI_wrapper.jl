
# MOI functions
const SVF = MOI.SingleVariable
const VOV = MOI.VectorOfVariables

# MOI indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# MOI types
const VAR_TYPES = Union{MOI.ZeroOne, MOI.Integer}

mutable struct Optimizer <: MOI.AbstractOptimizer
    solver::Solver
    status::MOI.TerminationStatusCode
end

function Optimizer(model = Model())
    Optimizer(Solver(model), MOI.OPTIMIZE_NOT_CALLED)
end

# forward functions from Solver
@forward Optimizer.solver variable!, _set_domain!, constraint!

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
struct DiscreteSet{V <: AbstractVector} <: MOI.AbstractScalarSet
    values::V
end