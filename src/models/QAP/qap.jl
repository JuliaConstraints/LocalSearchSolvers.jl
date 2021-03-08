include("read_instance.jl")

using LocalSearchSolvers
using JuMP

instance_name = "had12.dat"
instance = "/Users/pro/development/CSP/instances/" * instance_name

(n, W, D) = ReadInstance(instance);

model = JuMP.Model(LocalSearchSolvers.Optimizer)


@variable(model, permutations[1:n], DiscreteSet(1:n))
@constraint(model, permutations in LocalSearchSolvers.AllDifferent())

@objective(model, Min, WDSum);

WDSum = p -> sum( sum( W[p[i],p[j]]*D[i,j] for j in 1:n) for i in 1:n)

@objective(model, Min, WDSum);

optimize!(model)

solution = value.(permutations)
