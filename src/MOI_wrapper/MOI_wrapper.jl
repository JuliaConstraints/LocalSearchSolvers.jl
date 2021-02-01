mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Union{Solver, Nothing}
    # variable_info::Vector{Variable}
#     # which variable index, (:leq,:geq,:eq,:Int,:Bin), and lower and upper bound
    # var_constraints::Vector{Tuple{Int64,Symbol,Int64,Int64}}
#     status::MOI.TerminationStatusCode
#     options::SolverOptions
end

function Optimizer(; options...)
    @info options
    Optimizer(nothing)
end

MOI.get(::Optimizer, ::MOI.SolverName) = "LocalSearchSolvers"

MOI.set(::Optimizer, ::MOI.Silent, bool = true) = @warn "TODO: Silent"

function MOI.is_empty(model::Optimizer)
    isnothing(model.inner) ? true : _is_empty(model.inner)
end

"""
Copy constructor for the optimizer
"""
MOIU.supports_default_copy_to(model::Optimizer, copy_names::Bool) = !copy_names
function MOI.copy_to(model::Optimizer, src::MOI.ModelLike; kws...)
    return MOIU.automatic_copy_to(model, src; kws...)
end
