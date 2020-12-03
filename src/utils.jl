# TODO: use log instead
function _verbose(str::AbstractString, verbose::Bool)
    if verbose
        println(str)
    end
end

# Union to encapsulate single value or a vector
ValOrVect{T} = Union{T, AbstractVector{T}}
