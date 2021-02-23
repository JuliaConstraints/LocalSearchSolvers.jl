@enum PoolStatus empty_pool=0 halfway_pool unsat_pool mixed_pool full_pool

mutable struct _Pool{T}
    best::Int
    configurations::Vector{Configuration{T}}
    status::PoolStatus
    value::Float64
end

const Pool = Union{Nothing, _Pool}

pool() = nothing
function pool(config::Configuration)
    best = 1
    configs = [config]
    status = full_pool
    value = get_value(config)
    return _Pool(best, configs, status, value)
end 

is_empty(pool) = isnothing(pool)
best_config(pool) = pool.configurations[pool.best]
best_value(pool) = get_value(best_config(pool))
best_values(pool) = get_values(best_config(pool))

