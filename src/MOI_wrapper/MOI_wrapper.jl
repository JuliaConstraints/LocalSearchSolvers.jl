mutable struct Optimizer <: MOI.AbstractOptimizer
    solver::Solver
    # variable_info::Vector{Variable}
#     # which variable index, (:leq,:geq,:eq,:Int,:Bin), and lower and upper bound
    # var_constraints::Vector{Tuple{Int64,Symbol,Int64,Int64}}
    status::MOI.TerminationStatusCode
#     options::SolverOptions
end

function Optimizer(model = Model(); options...)
    @info options
    Optimizer(Solver(model), MOI.OPTIMIZE_NOT_CALLED)
end

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
    