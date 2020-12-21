"""
    all_equal(x::Int...; param::T)
    all_equal(x::Int...)
Global constraint ensuring that all the values of `x` are all_equal (to param if given).
"""
<<<<<<< HEAD
function c_all_equal(x::T...) where {T <: Number}
    acc = Dictionary{T,Int}()
=======
function all_equal(x::Int...)
    acc = Dictionary{Int, Int}()
>>>>>>> 173aaab... Coverage 100%
    foreach(y -> _insert_or_inc(acc, y), x)
    return Float64(length(x) - maximum(acc))
end

<<<<<<< HEAD
c_eq(x1::T, x2::T) where T = x1 == x2

function c_all_equal_param(x::T1...; param::T2) where {T1 <: Number,T2 <: Number}
=======
function equal_param(x::Int...; param::T) where T <: Number
>>>>>>> 173aaab... Coverage 100%
    acc = 0
    foreach(y -> y ≠ param && (acc += 1), x)
    return Float64(acc)
end
