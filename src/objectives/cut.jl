"""
    o_mincut(graph, values; interdiction = 0)
Compute the capacity of a cut (determined by the state of the solver) with a possible `interdiction` on the highest capacited links.
"""
function o_mincut(graph, values; interdiction = 0)
    capacity = Vector{Float64}()
    n = size(graph, 1)
    for i in 1:n, j in 1:n
        (values[i] < values[n + 1] < values[j]) && push!(capacity, graph[i, j])
    end
    return sum(sort!(capacity)[1:(end - interdiction)])
end
