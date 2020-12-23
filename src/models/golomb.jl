function golomb(n::Int, L::Int=n^2)
    m = Model()

    # Add variables
    d = domain(0:L)
    foreach(_ -> variable!(m, d), 1:n)

    # # Add constraints
    constraint!(m, c_all_different, 1:n)
    constraint!(m, x -> c_all_equal_param(x; param = 0), 1:1)
    for i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n
        (i, j) < (k, l) || continue
        constraint!(m, c_dist_different, [i, j, k, l])
    end

    # Add objective
    objective!(m, o_dist_extrema)

    return m
end
