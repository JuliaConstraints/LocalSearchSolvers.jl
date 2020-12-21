function mincut(m::AbstractMatrix{T}; source::Int, sink::Int) where {T <: Number}
    p = Problem()
    n = size(m, 1)

    d = domain(0:n)

    separator = n + 1 # value that separate the two sides of the cut

    # Add variables:
    foreach(_ -> variable!(p, d), 0:n)

    # Add constraint
    constraint!(p, c_ordered, [source, separator, sink])
    constraint!(p, c_all_different, 1:(n + 1))

    # Add objective
    objective!(p, (x...) -> o_mincut(m, x...))

    return p
end