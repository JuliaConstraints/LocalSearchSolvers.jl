function magic_square(n, ::Val{:JuMP})
    model = JuMP.Model(CBLS.Optimizer)
    magic_sum = n * (n^2 + 1) / 2;

    @variable(model, vars[1:9], DiscreteSet(1:9))
    @variable(model, magic_sum_var, DiscreteSet(magic_sum:magic_sum))


    @constraint(model, vars in CBLS.AllDifferent())

    #@constraint(model,[sum(vars[j] for j in 1:n), magic_sum_var] in CBLS.Eq())

    @constraint(model, vars[1:3] in LocalSearchSolvers.Predicate(_ -> (i -> reduce(+, i)) == magic_sum))
    #@constraint(model, vars in LocalSearchSolvers.Predicate(_ -> sum(vars[i] for i in 1:3) == magic_sum))

    #@constraint(model,sum(vars[j] for j in 1:n) == magic_sum)

    return model
end









