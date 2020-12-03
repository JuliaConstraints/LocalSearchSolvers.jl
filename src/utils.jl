# TODO: use log instead
function _verbose(str::AbstractString, verbose::Bool)
    if verbose
        println(str)
    end
end
