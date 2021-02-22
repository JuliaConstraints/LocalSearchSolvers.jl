@enum PoolStatus empty_pool=0 halfway_pool unsat_pool mixed_pool full_pool

mutable struct _Pool{T}
    best::Int
    configurations::Vector{Configuration{T}}
    status::PoolStatus
    value::Float64
end

const Pool = Union{Nothing, _Pool}

pool() = nothing
# function pool(config::Configuration)

#     best = 1
#     configs = [config]
#     status = halfway_pool

# end 

# Pool{T}() where {T} = Pool(0, Vector{Configuration{T}}(), empty_pool, Inf)

is_empty(pool) = isnothing(pool)
best_config(pool) = configurations[pool.best]