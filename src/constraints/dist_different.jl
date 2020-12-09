"""
    dist_different(i::T, j::T, k::T, l::T) where {T <: Number}
Local constraint ensuring that `|i - j| ≠ |k - l|`.
"""
function dist_different(i::T, j::T, k::T, l::T) where {T <: Number}
    return abs(i - j) ≠ abs(k - l) ? 0.0 : 1.0
end
