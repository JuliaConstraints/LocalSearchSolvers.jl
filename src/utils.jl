# TODO: use log instead
function _verbose(str::AbstractString, verbose::Bool)
    if verbose
        println(str)
    end
end

# Union to encapsulate single value or a vector
_ValOrVect{T} = Union{T,AbstractVector{T}}
_datatype_to_union(dt::_ValOrVect) = Union{(isa(dt, Type) ? [dt] : dt)...}
# _filter(dt::_ValOrVect, T) = filter(x -> x <: T, isa(dt, Type) ? [dt] : dt)
