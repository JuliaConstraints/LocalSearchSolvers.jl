"""
    _to_union(datatype)
Make a minimal `Union` type from a collection of data types.
"""
_to_union(datatype) = Union{(isa(datatype, Type) ? [datatype] : datatype)...}

"""
    _find_rand_argmax(d::DictionaryView)
Compute `argmax` of `d` and select one element randomly.
"""
function _find_rand_argmax(d::DictionaryView)
    max = -Inf
    argmax = Vector{Int}()
    for (k, v) in pairs(d)
        if v > max
            max = v
            argmax = [k]
        elseif v == max
            push!(argmax, k)
        end
    end
    return rand(argmax)
end

abstract type FunctionContainer end
apply(fc::FC) where {FC <: FunctionContainer} = fc.f
apply(fc::FC, x, X) where {FC <: FunctionContainer} = convert(Float64, apply(fc)(x, X))
apply(fc::FC, x) where {FC <: FunctionContainer} = convert(Float64, apply(fc)(x))
