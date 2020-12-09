function golomb(n::Int, L::Int=n^2)
    d = domain(Vector{Int}(0:(L - 1)))
    p = Problem()

    # Add variables
    foreach(_ -> variable!(p, d), 1:n)

    # Add constraints
    for i in 1:(n - 1), j in i:n
        describe(p)
        for l in i:n
            j == l && continue
            constraint!(p, dist_different, [i, j, i, l])
        end
        for k in (i + 1):(n - 1), l in k:n
            (i, j) == (k, l) && continue
            constraint!(p, dist_different, [i, j, k, l])
        end
    end

    # Add objective
    objective!(p, dist_extrema)

    return p
end
