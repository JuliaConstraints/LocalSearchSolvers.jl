"""
    _to_union(datatype)
Make a minimal `Union` type from a collection of data types.
"""
_to_union(datatype) = Union{(isa(datatype, Type) ? [datatype] : datatype)...}

"""
    _find_rand_argmax(d, excluded = nothing)

Compute `argmax` of `d` while ignoring keys present in `excluded`. Ties use reservoir
sampling, which preserves uniform random selection without materializing a candidate vector.
"""
function _find_rand_argmax(d, excluded = nothing)
    maximum_value = -Inf
    selected = nothing
    ties = 0
    for (key, value) in pairs(d)
        excluded === nothing || !haskey(excluded, key) || continue
        if value > maximum_value
            maximum_value = value
            selected = key
            ties = 1
        elseif value == maximum_value
            ties += 1
            rand(1:ties) == 1 && (selected = key)
        end
    end
    selected === nothing && throw(ArgumentError("argmax requires a non-empty candidate set"))
    return selected
end

function _find_rand_argmax!(
    candidates::Vector{Int},
    d,
    excluded = nothing;
    fallback_on_all_excluded::Bool = false,
)
    empty!(candidates)
    maximum_value = -Inf
    for (key, value) in pairs(d)
        excluded === nothing || !haskey(excluded, key) || continue
        if value > maximum_value
            maximum_value = value
            empty!(candidates)
            push!(candidates, key)
        elseif value == maximum_value
            push!(candidates, key)
        end
    end
    if isempty(candidates) && fallback_on_all_excluded && excluded !== nothing
        return _find_rand_argmax!(candidates, d)
    end
    isempty(candidates) && throw(ArgumentError("argmax requires a non-empty candidate set"))
    return rand(candidates)
end

@testitem "Random argmax filters keys without a temporary candidate collection" default_imports=false begin
    import Dictionaries: Dictionary
    import LocalSearchSolvers as LS
    import Test: @test, @test_throws

    costs = Dictionary([1, 2, 3, 4], [1.0, 3.0, 3.0, 2.0])
    tabu = Dictionary([2], [1])
    @test all(==(3), (LS._find_rand_argmax(costs, tabu) for _ in 1:20))
    @test LS._find_rand_argmax(costs) in (2, 3)
    @test_throws ArgumentError LS._find_rand_argmax(costs, Dictionary(1:4, ones(Int, 4)))
    candidates = Int[]
    @test LS._find_rand_argmax!(candidates, costs, tabu) == 3
    @test candidates == [3]
end

abstract type FunctionContainer end
apply(fc::FC) where {FC <: FunctionContainer} = fc.f
apply(fc::FC, x, X) where {FC <: FunctionContainer} = convert(Float64, apply(fc)(x; X))
apply(fc::FC, x) where {FC <: FunctionContainer} = convert(Float64, apply(fc)(x))
