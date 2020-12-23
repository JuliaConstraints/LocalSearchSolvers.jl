function mincut(graph::AbstractMatrix{T}; source::Int, sink::Int) where {T <: Number}
    m = Model()
    n = size(graph, 1)

    d = domain(0:n)

    separator = n + 1 # value that separate the two sides of the cut

    # Add variables:
    foreach(_ -> variable!(m, d), 0:n)

    # Add constraint
    constraint!(m, c_ordered, [source, separator, sink])
    constraint!(m, c_all_different, 1:(n + 1))

    # Add objective
    objective!(m, (x...) -> o_mincut(graph, x...))

    return m
end
