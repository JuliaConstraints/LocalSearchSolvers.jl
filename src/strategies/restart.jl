abstract type RestartStrategy end

# Random restart
struct RandomRestart <: RestartStrategy
    reset_percentage::Float64
end

function restart(::Any, ::Val{:random}; rp=0.05)
    return RandomRestart(rp)
end

function check_restart!(rs::RandomRestart; tabu_length=nothing)
    return rand() ≤ rs.reset_percentage
end

# Tabu restart
mutable struct TabuRestart <: RestartStrategy
    index::Int
    tenure::Int
    limit::Int
    reset_percentage::Float64
end

function restart(tabu_strat, ::Val{:tabu}; rp=1.0, index=1)
    limit = tenure(tabu_strat, :tabu) - tenure(tabu_strat, :pick)
    return TabuRestart(index, tenure(tabu_strat, :tabu), limit, rp)
end

function check_restart!(rs::TabuRestart; tabu_length)
    a = rs.index * (tabu_length + rs.limit - rs.tenure)
    b = (rs.index + 1) * rs.limit
    # a = tabu_length + rs.limit - rs.tenure
    # b = rs.limit
    if rand() ≤ a / b
        rs.index += 1
        return true
    end
    return false
end

# Restart sequences
mutable struct RestartSequence{F<:Function} <: RestartStrategy
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

function check_restart!(rs::RestartSequence; tabu_length=nothing)
    proceed = rs.current > rs.last_restart
    proceed ? inc_last!(rs) : next!(rs)
    return !proceed
end

## Universal restart sequence

function oeis(n, b, ::Val{:A082850})
    m = log(b, n + 1)
    return isinteger(m) ? Int(m) : oeis(n - (b^floor(m) - 1), :A082850)
end
oeis(n, b, ::Val{:A182105}) = b^(oeis(n, :A082850) - 1)
oeis(n, ref::Symbol, b=2) = oeis(n, b, Val(ref))
restart(::Any, ::Val{:universal}) = RestartSequence(n -> oeis(n, :A182105))

# Generic restart constructor
restart(tabu, strategy::Symbol) = restart(tabu, Val(strategy))
