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
    get!(settings, :threads, typemax(0))
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
