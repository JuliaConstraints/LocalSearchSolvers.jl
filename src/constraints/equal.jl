"""
    all_equal(x::Int...; param::T)
    all_equal(x::Int...)
Global constraint ensuring that all the values of `x` are all_equal (to param if given).
"""
function all_equal(x::Int...) # TODO: fix name conflict
    acc = Dictionary{Int, Int}()
    foreach(y -> _insert_or_inc(acc, y), x)
    return Float64(length(x) - max(acc))
end

function all_equal(x::Int...; param::T) where T <: Number
    acc = 0
    foreach(y -> y ≠ param && (acc += 1), x)
    return Float64(acc)
end
