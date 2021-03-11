struct PrintLevel <: MOI.AbstractOptimizerAttribute end

MOI.set(model::Optimizer, ::PrintLevel, level::Symbol) = _print_level!(model, level)

MOI.supports(::Optimizer, ::PrintLevel) = true
MOI.supports(::Optimizer, ::MOI.RawParameter) = true
