function o_mincut(m::AbstractMatrix{T}, values::Int...; interdiction::Int = 0
) where {T <: Number}
    capacity = Vector{Float64}()
    n = size(m, 1)
    for i in 1:n, j in 1:n
        (values[i] < values[n + 1] < values[j]) && push!(capacity, m[i, j])
    end
    return sum(sort!(capacity)[1:(end - interdiction)])
end
