function mincut(n::Int)
    p = Problem()
    d_s = domain([0])
    d_t = domain([n])
    d = domain(Vector{Int}(1:(n-1)))

    
    foreach(_ -> variable!(p, d), 1:(n-1))

    return p
end