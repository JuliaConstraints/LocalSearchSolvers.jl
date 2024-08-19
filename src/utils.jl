# SECTION - UTILITIES

"""
    _to_union(datatype)

Make a minimal `Union` type from a collection of data types.

# Arguments
- `datatype`: A single type or a collection of types.

# Returns
A `Union` type containing the unique types from `datatype`.

# Examples
```julia-repl
julia> _to_union(Int)
Int64

julia> _to_union([Int, Float64, Int])
Union{Float64, Int64}
```
"""
_to_union(datatype) = Union{(isa(datatype, Type) ? [datatype] : datatype)...}

"""
    _find_rand_argmax(d::DictionaryView)

Compute the `argmax` of `d` and select one element randomly if there are multiple maximum values.

# Arguments
- `d::DictionaryView`: A dictionary view.

# Returns
A random key from `d` that has the maximum value.
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

"""
    abstract type FunctionContainer

An abstract type for function containers.
"""
abstract type FunctionContainer end

"""
    apply(fc::FC) where {FC <: FunctionContainer}
    apply(fc::FC, x) where {FC <: FunctionContainer}
    apply(fc::FC, x, X) where {FC <: FunctionContainer}

Apply the function stored in `fc`.

# Arguments
- `fc::FC`: A function container.
- `x`: A single input. (optional)
- `X`: A collection of inputs. (optional)

# Returns
The result of applying the function stored in `fc`.
"""
apply(fc::FC) where {FC <: FunctionContainer} = fc.f
apply(fc::FC, x, X) where {FC <: FunctionContainer} = convert(Float64, apply(fc)(x; X))
apply(fc::FC, x) where {FC <: FunctionContainer} = convert(Float64, apply(fc)(x))

@testitem "Utils: _to_union" tags=[:utils, :union] begin
    import LocalSearchSolvers: _to_union
    @test _to_union(Int) === Int
    @test _to_union([Int, Float64, Int]) === Union{Float64, Int}
end

@testitem "Utils: _find_rand_argmax" tags=[:utils, :argmax] default_imports=false begin
    import Dictionaries
    import LocalSearchSolvers: _find_rand_argmax
    import Test: @test
    d = Dictionaries.Dictionary(1:3, [1, 2, 1])
    dv = view(d, Dictionaries.Indices([1, 3]))

    @test _find_rand_argmax(dv) in [1, 3]
end

@testitem "Utils: FunctionContainer" tags=[:utils, :function_container] default_imports=false begin
    import LocalSearchSolvers: FunctionContainer, apply
    import Test: @test

    struct FC <: FunctionContainer
        f::Function
    end

    f(x; X) = x + sum(X)
    fc = FC(f)

    @test apply(fc, 1, [1, 2, 3]) === 7.0

    f(x) = x + 1.0
    fc = FC(f)

    @test apply(fc, 1) === 2.0
end
