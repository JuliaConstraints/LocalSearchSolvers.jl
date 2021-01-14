function mincut(graph::AbstractMatrix{T}; source::Int, sink::Int, interdiction::Int=0) where {T <: Number}
    m = Model()
    n = size(graph, 1)

    d = domain(0:n)

    separator = n + 1 # value that separate the two sides of the cut

    # Add variables:
    foreach(_ -> variable!(m, d), 0:n)

    # Extract error function from usual_constraint
    e1 = (x; param=nothing, dom_size=n + 1) -> error_f(
        usual_constraints[:ordered])(x; param=param, dom_size=dom_size
    )
    e2 = (x; param=nothing, dom_size=n + 1) -> error_f(
        usual_constraints[:all_different])(x; param=param, dom_size=dom_size
    )

    # Add constraint
    constraint!(m, e1, [source, separator, sink])
    constraint!(m, e2, 1:(n + 1))

    # Add objective
    objective!(m, (x...) -> o_mincut(graph, x...; interdiction=interdiction))

    return m
end
