@enum PoolStatus empty_pool halfway_pool unsat_pool mixed_pool full_pool

mutable struct Pool{T <: Number}
    best::Int
    configurations::Vector{Configuration{T}}
    status::PoolStatus
    value::Float64
end

Pool() where {T <: Number}= Pool(0, Vector{Configuration{T}}(), empty_pool, Inf)