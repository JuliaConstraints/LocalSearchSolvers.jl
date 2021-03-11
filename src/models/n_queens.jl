function n_queens(n, ::Val{:JuMP})
    model = JuMP.Model(CBLS.Optimizer)

    @variable(model, queens[1:n], DiscreteSet(1:n))
    @constraint(model, queens in CBLS.AllDifferent())

    for i in 1:n
        for j in i+1:n
            @constraint(model, [queens[i],queens[j]] in Predicate(x -> x[1] != x[2]))
            @constraint(model, [queens[i],queens[j]] in Predicate(x -> (x[1] != x[2]+i-j)))
            @constraint(model, [queens[i],queens[j]] in Predicate(x -> (x[1] != x[2]+j-i)))
        end
    end

    return model, queens
end

"""
    n_queens(n; modeler = :JuMP)

Create a model for the n-queens problem with `n` queens. The `modeler` argument accepts :JuMP (default), which refer to the JuMP model.
"""
n_queens(n; modeler = :JuMP) = n_queens(n, Val(modeler))
