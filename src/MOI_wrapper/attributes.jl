struct PrintLevel <: MOI.AbstractOptimizerAttribute end

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

"""
    MOI.set(model::Optimizer, p::MOI.RawParameter, value)
Set a RawParameter to `value`
"""
function MOI.set(model::Optimizer, p::MOI.RawParameter, value)
    eval(Symbol("_" * p.name * "!"))(model, value)
end

function MOI.get(model::Optimizer, p::MOI.RawParameter)
    eval(Symbol("_" * p.name))(model)
end