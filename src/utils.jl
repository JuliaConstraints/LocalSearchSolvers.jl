Settings = Dict{Symbol, Any}

# TODO: use log instead
function _verbose(settings::Settings, str::AbstractString)
    settings[:verbose] && println(str)
end

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
