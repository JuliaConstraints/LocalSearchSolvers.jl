# TODO: MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{ScalarFunction{F}}) where {F <: Function} = true

# TODO: sense
# MOI.get(model::Optimizer, ::MOI.ObjectiveSense) = model.inner.sense

# function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
#     model.inner.sense = sense
#     return
# end

function MOI.set(optimizer::Optimizer, ::MOI.ObjectiveFunction, func::ScalarFunction)
    objective!(optimizer, func.f)
end
