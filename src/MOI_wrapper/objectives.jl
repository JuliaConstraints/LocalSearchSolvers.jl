MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.get(model::Optimizer, ::MOI.ObjectiveSense) = Min
function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    @warn "TODO: set sense" sense
end

MOI.supports(::Optimizer, ::OF{ScalarFunction{F, V}}) where {F <: Function, V <: Union{Nothing, SVF,VOV}} = true

function MOI.set(optimizer::Optimizer, ::OF, func::ScalarFunction{F, V}
) where {F <: Function, V <: Union{Nothing, VOV}}
    objective_function = if isnothing(func.X)
        func.f
    else # VOV
        _ -> func.f(map(y -> _value(optimizer,y.value), func.X.variables))
    end
    objective!(optimizer, objective_function)
end
