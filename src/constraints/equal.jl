"""
    all_equal(x::Int...; param::T)
    all_equal(x::Int...)
Global constraint ensuring that all the values of `x` are all_equal (to param if given).
"""
function c_all_equal(x::T...) where {T <: Number}
    acc = Dictionary{T,Int}()
    foreach(y -> _insert_or_inc(acc, y), x)
    return Float64(length(x) - maximum(acc))
end

c_eq(x1, x2) = x1 == x2

function c_all_equal_param(x::T1...; param::T2) where {T1 <: Number,T2 <: Number}
    acc = 0
    foreach(y -> y ≠ param && (acc += 1), x)
    return Float64(acc)
end
