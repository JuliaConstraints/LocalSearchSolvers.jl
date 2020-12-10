"""
    all_different(x::Int...)
Global constraint ensuring that all the values of `x` are unique.
"""
function all_different(x::Int...) # TODO: make a better function
    acc = Dictionary{Int, Int}()
    foreach(y -> _insert_or_inc(acc, y), x)
    return Float64(sum(acc .- 1))
end
