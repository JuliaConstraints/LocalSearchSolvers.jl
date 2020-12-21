"""
    all_different(x::Int...)
Global constraint ensuring that all the values of `x` are unique.
"""
function c_all_different(x::T...) where {T <: Number}
    acc = Dictionary{T, Int}()
    foreach(y -> _insert_or_inc(acc, y), x)
    return Float64(sum(acc .- 1))
end
