function golomb(n::Int, L::Int=n^2)
    m = Model()

    # Add variables
    d = domain(0:L)
    foreach(_ -> variable!(m, d), 1:n)

    # Extract error function from usual_constraint
    e1 = error_f(usual_constraints[:all_different])
    e2 = error_f(usual_constraints[:all_equal_param])
    e3 = error_f(usual_constraints[:dist_difference])

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
