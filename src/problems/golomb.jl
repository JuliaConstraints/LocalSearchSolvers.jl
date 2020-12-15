function golomb(n::Int, L::Int=n^2)    
    d_0 = domain([0])
    d = domain(Vector{Int}(0:L))
    p = Problem()

    # Add variables
    variable!(p, d_0)
    foreach(_ -> variable!(p, d), 2:n)

    # # Add constraints
    constraint!(p, all_different, 1:n)
    for i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n
        (i, j) < (k, l) || continue
        constraint!(p, dist_different, [i, j, k, l])
    end

    # Add objective
    objective!(p, dist_extrema)

    return p
end
