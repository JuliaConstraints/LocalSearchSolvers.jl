function mincut(m::AbstractMatrix{T}; source::Int, sink::Int) where {T <: Number}
    p = Problem()
    n = size(m, 1)

    d = domain(0:n)

    # Add variables:
    foreach(_ -> variable!(p, d), 0:n)

    # Add constraint
    constraint!(p, x -> all_equal(x; param = 0), source:source)
    constraint!(p, x -> all_equal(x; param = n), sink:sink)

    return p
end
