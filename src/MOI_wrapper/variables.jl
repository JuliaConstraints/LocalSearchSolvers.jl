MOI.add_variable(model::Optimizer) = variable!(model)
MOI.add_variables(model::Optimizer, n::Int) = [MOI.add_variable(model) for i in 1:n]