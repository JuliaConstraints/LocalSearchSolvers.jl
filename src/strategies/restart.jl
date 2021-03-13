abstract type RestartStrategy end

# Tabu restart
struct TabuRestart <: RestartStrategy
    reset_limit::Int
    reset_percentage::Float64
end

restart(strat,::Val{:tabu}) = TabuRestart(tenure(strat, :tabu) - tenure(strat, :pick), 1.0)

check_restart!(rs::TabuRestart; tabu_length) = rs.reset_limit ≤ tabu

# Restart sequences
mutable struct RestartSequence{F <: Function} <: RestartStrategy
    index::Int
    current::Int
    last_restart::Int
    next::F

    RestartSequence(seq) = new{typeof(seq)}(1, seq(1), 1, seq)
end

current(r) = r.current

function next!(r)
    r.index += 1
    r.current = r.next(r.index)
    r.last_restart = 1
    return r.current
end

inc_last!(rs) = rs.last_restart += 1

function check_restart!(rs::RestartSequence; tabu_length = nothing)
    proceed = rs.current > rs.last_restart
    proceed ? inc_last!(rs) : next!(rs)
    return !proceed
end

## Universal restart sequence

function oeis(n, b, ::Val{:A082850})
    m = log(b,n+1)
    return isinteger(m) ? Int(m) : oeis(n - (b^floor(m) - 1), :A082850)
end
oeis(n, b, ::Val{:A182105}) = b^(oeis(n, :A082850)-1)
oeis(n, ref::Symbol, b = 2) = oeis(n, b, Val(ref))
restart(::Val{:universal}) = RestartSequence(n -> oeis(n, :A182105))

# Generic restart constructor
restart(strategy::Symbol) = restart(Val(strategy))