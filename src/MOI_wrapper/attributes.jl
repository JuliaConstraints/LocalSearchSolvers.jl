struct PrintLevel <: MOI.AbstractOptimizerAttribute end

function MOI.set(model::Optimizer, ::PrintLevel, level::Int)

end
