function golomb(n, L, ::Val{:raw})
    m = CBLS.Model(; kind=:golomb)

    # Add variables
    d = domain(0:L)
    foreach(_ -> variable!(m, d), 1:n)

    # Extract error function from usual_constraint
    e1 = (x; param=nothing, dom_size=n) -> error_f(
        usual_constraints[:all_different])(x; param=param, dom_size=dom_size
    )
    e2 = (x; param=nothing, dom_size=n) -> error_f(
        usual_constraints[:all_equal_param])(x; param=param, dom_size=dom_size
    )
    e3 = (x; param=nothing, dom_size=n) -> error_f(
        usual_constraints[:dist_different])(x; param=param, dom_size=dom_size
    )

    # # Add constraints
    constraint!(m, e1, 1:n)
    constraint!(m, x -> e2(x; param=0), 1:1)
    for i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n
        (i, j) < (k, l) || continue
        constraint!(m, e3, [i, j, k, l])
    end

    # Add objective
    objective!(m, o_dist_extrema)

    return m
end

function golomb(n, L, ::Val{:JuMP})
    m = JuMP.Model(CBLS.Optimizer)

    @variable(m, X[1:n], DiscreteSet(0:L))

    # @constraint(m, X[1] in AllEqualParam(0)) # first mark at 0

    @constraint(m, X in AllDifferent()) # different marks

    # No two pairs have the same length
    for i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n
        (i, j) < (k, l) || continue
        @constraint(m, [X[i], X[j], X[k], X[l]] in DistDifferent())
    end

    # Add objective
    # @objective(m, Min, X in DistExtrema())
    @objective(m, Min, CBLS.ScalarFunction(sum, X))

    return m, X
end

"""
    golomb(n, L=n²)

Model the Golomb problem of `n` marks on the ruler `0:L`. The `modeler` argument accepts :raw, and :JuMP (default), which refer respectively to the solver internal model, the MathOptInterface model, and the JuMP model.
"""
golomb(n, L=n^2; modeler = :JuMP) = golomb(n, L, Val(modeler))
