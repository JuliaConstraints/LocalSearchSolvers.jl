function mincut(m::AbstractMatrix{T}, values::Int...) where {T <: Number}
    capacity = 0.0
    n = size(m, 1)
    for i in 1:n, j in 1:n
        (values[i] < values[n + 1] < values[j]) && (capacity += m[i, j])
    end
    return capacity
end
