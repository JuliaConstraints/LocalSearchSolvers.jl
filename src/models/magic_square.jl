sum_equal_param(param) = x -> sum(x) == param

function magic_square(n, ::Val{:JuMP})
    N = n^2
    model = JuMP.Model(CBLS.Optimizer)
    magic_constant = n * (N + 1) / 2
    Σeq = sum_equal_param(magic_constant)

    @variable(model, X[1:n, 1:n], DiscreteSet(1:N))
    @constraint(model, vec(X) in AllDifferent())

    for i in 1:n
        @constraint(model, X[i,:] in Predicate(Σeq))
        @constraint(model, X[:,i] in Predicate(Σeq))
    end
    @constraint(model, [X[i,i] for i in 1:n] in Predicate(Σeq))
    @constraint(model, [X[i,n + 1 - i] for i in 1:n] in Predicate(Σeq))

    return model, X
end

magic_square(n; modeler = :JuMP) = magic_square(n, Val(modeler))








