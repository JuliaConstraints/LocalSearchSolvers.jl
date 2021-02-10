MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.get(model::Optimizer, ::MOI.ObjectiveSense) = Min
function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    @warn "TODO: set sense" sense
end

"""
    ScalarFunction(func, X)
"""
struct ScalarFunction{F <: Function, V <: Union{Nothing, VOV}} <: MOI.AbstractScalarFunction
    f::F
    X::V

    ScalarFunction(f, X::Union{Nothing, VOV} = nothing) = (@warn X; new{typeof(f), typeof(X)}(f, X))
end

# external constructors

function ScalarFunction(f, X::A) where {A <: AbstractArray{VariableRef}}
    return ScalarFunction(f, VOV(vec(map(index, X))))
end
ScalarFunction(f, x::VariableRef) = ScalarFunction(f, [x])
ScalarFunction(f, x::VI) = ScalarFunction(f, VOV([x]))

# copy
Base.copy(func::ScalarFunction) = ScalarFunction(func.f, func.X)

# supports
MOI.supports(::Optimizer, ::OF{ScalarFunction{F, V}}) where {F <: Function, V <: Union{Nothing, SVF,VOV}} = true

# set
function MOI.set(optimizer::Optimizer, ::OF, func::ScalarFunction{F, V}
) where {F <: Function, V <: Union{Nothing, VOV}}
    objective_function = if isnothing(func.X) # for direct use of MOI
        func.f
    else # VOV, mainly for JuMP
        _ -> func.f(map(y -> _value(optimizer,y.value), func.X.variables))
    end
    objective!(optimizer, objective_function)
end
