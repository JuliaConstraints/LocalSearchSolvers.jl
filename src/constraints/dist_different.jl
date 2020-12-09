"""
    dist_different(i::T, j::T, k::T, l::T) where {T <: Number}
Local constraint ensuring that `|i - j| ≠ |k - l|`.
"""
function dist_different(i::T, j::T, k::T, l::T) where {T <: Number}
    return Float64(abs(i - j) = abs(k - l))
end
