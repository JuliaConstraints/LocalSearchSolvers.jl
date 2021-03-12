struct PrintLevel <: MOI.AbstractOptimizerAttribute end

MOI.set(model::Optimizer, ::PrintLevel, level::Symbol) = _print_level!(model, level)

MOI.supports(::Optimizer, ::PrintLevel) = true

MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

"""
    MOI.set(model::Optimizer, ::MOI.RawParameter, value)
Set the time limit
"""
function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing,Float64})
    _time_limit!(model, value === nothing ? zero(Float64) : value)
end
MOI.get(model::Optimizer, ::MOI.TimeLimitSec) = _time_limit(model)

