#using Pkg
#Pkg.add("GLPK")

using JuMP
using GLPK

model = Model(GLPK.Optimizer)
@variable(model, 0 <= x <= 20, Int)
@variable(model, 0 <= y <= 20, Int)

@constraint(model, 6x + 8y >= 100 )
@constraint(model, 7x + 12y >= 120)

@objective(model, Min, 12x + 20y)

optimize!(model)

@show value(x);
@show value(y);
@show objective_value(model);

##

using JuMP
using LocalSearchSolvers

model = Model(LocalSearchSolvers.Optimizer)
@variable(model, x in DiscreteSet(0:20))
@variable(model, y in DiscreteSet(0:20))

@constraint(model, [x,y] in Predicate(v -> 6v[1] + 8v[2] >= 100 ))
@constraint(model, [x,y] in Predicate(v -> 7v[1] + 12v[2] >= 120 ))

objFunc = v -> 12v[1] + 20v[2]
@objective(model, Min, ScalarFunction(objFunc))



optimize!(model)

@show value(x);
@show value(y);
@show (12*value(x)+20*value(y))
