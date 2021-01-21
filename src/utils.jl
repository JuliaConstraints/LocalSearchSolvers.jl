"""
    Settings
Dictionary to store the settngs of a solver.
```
default = Settings(
    :iteration => 1000,
    :specialize => true,
    :verbose => false,
    :threads => typemax(0),
)
```
By default, the number of threads used is the maximum available. Otherwise, it is minimum between `default[:threads]` and the number of available threads.
"""
Settings = Dict{Symbol, Any}


"""
    _verbose(settings, str)
Temporary logging function. #TODO: use better log instead (LoggingExtra.jl)
"""
function _verbose(settings, str)
    settings[:verbose] && (@info str)
end

"""
    _to_union(datatype)
Make a minimal `Union` type from a collection of data types.
"""
_to_union(datatype) = Union{(isa(datatype, Type) ? [datatype] : datatype)...}

"""
    _make_settings!(settings)
Make default settings unless, for each setting, already provided by the user.
"""
function _make_settings!(settings)
    get!(settings, :iteration, 1000)
    get!(settings, :specialize, true)
    get!(settings, :verbose, false)
    get!(settings, :threads, typemax(0))
    return nothing
end

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
