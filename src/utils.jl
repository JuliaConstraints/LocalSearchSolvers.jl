Settings = Dict{Symbol, Any}

# TODO: use better log instead (LoggingExtra.jl)
function _verbose(settings::Settings, str::AbstractString)
    settings[:verbose] && (@info str)
end

# Union to encapsulate single value or a vector
_ValOrVect{T} = Union{T,AbstractVector{T}}
_datatype_to_union(dt::_ValOrVect) = Union{(isa(dt, Type) ? [dt] : dt)...}

# Default settings
function make_settings!(settings::Dict{Symbol, Any})
    get!(settings, :iteration, 1000)
    get!(settings, :specialize, true)
    get!(settings, :verbose, false)
    return nothing
end

# rand argmax
function _find_rand_argmax(d::DictionaryView{Int,Float64})
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


# """
#     _map_tr(f, x)
#     _map_tr(f, x, param)
# Return an anonymous function that applies `f` to all elements of `x`, with an optional parameter `param`.
# """
# _map_tr(f, x::AbstractVector) = ((g, y) -> map(i -> g(i, y), 1:length(y)))(f, x)
# _map_tr(f, x, param) = ((g, y, p) -> map(i -> g(i, y, p), 1:length(y)))(f, x, param)

# """
#     lazy(funcs::Function...)
#     lazy_param(funcs::Function...)
# Generate methods extended to a vector instead of one of its components. For `lazy` (resp. `lazy_param`) a function `f` should have the following signature: `f(i::Int, x::V)` (resp. `f(i::Int, x::V, param::T)`).
# """
# function lazy(funcs::Function...)
#     foreach(f -> eval(:($f(x) = (y -> _map_tr($f, y))(x))), map(Symbol, funcs))
# end
# function lazy_param(funcs::Function...)
#     foreach(f -> eval(:($f(x, param) = (y -> _map_tr($f, y, param))(x))), map(Symbol, funcs))
# end