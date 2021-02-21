@enum PoolStatus empty_pool halfway_pool unsat_pool mixed_pool full_pool

mutable struct Pool{T}
    best::Int
    configurations::Vector{Configuration{T}}
    status::PoolStatus
    value::Float64
end

Pool{T}() where {T} = Pool(0, Vector{Configuration{T}}(), empty_pool, Inf)

is_empty(pool) = pool.status == empty_pool

best_config(pool) = configurations[pool.best]