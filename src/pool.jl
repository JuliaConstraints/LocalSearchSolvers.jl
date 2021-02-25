abstract type AbstractPool end

struct EmptyPool end

@enum PoolStatus empty_pool=0 halfway_pool unsat_pool mixed_pool full_pool

mutable struct _Pool{T} <: AbstractPool
    best::Int
    configurations::Vector{Configuration{T}}
    status::PoolStatus
    value::Float64
end

const Pool = Union{EmptyPool, _Pool}

pool() = EmptyPool()
function pool(config::Configuration)
    best = 1
    configs = [config]
    status = full_pool
    value = get_value(config)
    return _Pool(best, configs, status, value)
end 

is_empty(::EmptyPool) = true
is_empty(pool) = isempty(pool.configurations)
best_config(pool) = pool.configurations[pool.best]
best_value(pool) = get_value(best_config(pool))
best_values(pool) = get_values(best_config(pool))

