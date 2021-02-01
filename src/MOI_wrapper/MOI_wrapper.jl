mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::Union{Solver, Nothing}
    variable_info::Vector{Variable}
#     # which variable index, (:leq,:geq,:eq,:Int,:Bin), and lower and upper bound
    var_constraints::Vector{Tuple{Int64,Symbol,Int64,Int64}}
#     status::MOI.TerminationStatusCode
#     options::SolverOptions
end

function Optimizer(; options...)
    @info options
    Optimizer(nothing)
end

@autodocs
function MOI.is_empty(model::Optimizer)
    return isempty(model.variable_info) && isempty(model.var_constraints)
end
