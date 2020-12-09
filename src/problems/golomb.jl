function golomb(n::Int, L::Int = n^2)
    d = domain(Vector{Int}(0:(L-1))
    p = Problem()

    # Add variables
    foreach(_ -> variable!(p, d), 1:n)

    # Add constraint
    for i in 1:(n - 1), j in i:n, k in 1:(n - 1), l in k:n
        (i, j) == (k, l) && continue
        constr
    end
end
