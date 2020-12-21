"""
    dist_extrema(values::T...) where {T <: Number}
Computes the distance between extrema in an ordered set.
"""
function o_dist_extrema(values::T...) where {T <: Number}
    m, M = extrema(values)
    return Float64(M - m)
end
