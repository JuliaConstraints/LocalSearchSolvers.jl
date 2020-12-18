# Alias to make solver settings user-friendly
Settings = Dict{Symbol, Any}

# Union to encapsulate single value or a vector
_ValOrVect{T} = Union{T,AbstractVector{T}}
_datatype_to_union(dt::_ValOrVect) = Union{(isa(dt, Type) ? [dt] : dt)...}
# _filter(dt::_ValOrVect, T) = filter(x -> x <: T, isa(dt, Type) ? [dt] : dt)

# Default settings
function make_settings!(settings::Dict{Symbol, Any})
    get!(settings, :iteration, 1000)
    get!(settings, :specialize, true)
    get!(settings, :verbose, false)
    return nothing
end

# # conserve or insert
# consert!(d::Dict, k, v) = k ∉ keys(d) && insert!(d, k, v)

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
    # println("argmax : $argmax\n") # TODO: verbose/log
    return rand(argmax)
end
