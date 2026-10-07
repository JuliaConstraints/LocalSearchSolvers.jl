abstract type RestartStrategy end

"""Reset on exhausted selection or a tabu-count threshold, with periodic full restarts."""
mutable struct ExhaustionRestart <: RestartStrategy
    tabu_threshold::Int
    reset_fraction::Float64
    full_every::Int
    resets::Int
    function ExhaustionRestart(; tabu_threshold=typemax(Int), reset_fraction=0.1, full_every=0)
        tabu_threshold > 0 || throw(ArgumentError("tabu threshold must be positive"))
        0 < reset_fraction <= 1 || throw(ArgumentError("reset fraction must be in (0,1]"))
        full_every >= 0 || throw(ArgumentError("full restart period must be non-negative"))
        new(tabu_threshold, reset_fraction, full_every, 0)
    end
end
restart_fraction(rs::ExhaustionRestart) =
    rs.full_every > 0 && rs.resets % rs.full_every == 0 ? 1.0 : rs.reset_fraction
export ExhaustionRestart

"A restart trigger paired with a state source and perturbation fraction."
struct RestartPolicy{T <: RestartStrategy} <: RestartStrategy
    trigger::T
    reset_fraction::Float64
    source::Symbol

    function RestartPolicy(trigger::T; reset_fraction::Real = 1.0,
            source::Symbol = :current) where {T <: RestartStrategy}
        0.0 <= reset_fraction <= 1.0 ||
            throw(ArgumentError("restart reset_fraction must be in [0, 1]"))
        source in (:current, :best) ||
            throw(ArgumentError("restart source must be :current or :best"))
        return new{T}(trigger, Float64(reset_fraction), source)
    end
end

restart_fraction(::RestartStrategy) = 1.0
restart_fraction(policy::RestartPolicy) = policy.reset_fraction
restart_source(::RestartStrategy) = :current
restart_source(policy::RestartPolicy) = policy.source
check_restart!(policy::RestartPolicy; kwargs...) = check_restart!(policy.trigger; kwargs...)

# Random restart
struct RandomRestart <: RestartStrategy
    reset_percentage::Float64
end

function restart(::Any, ::Val{:random}; rp = 0.05)
    return RandomRestart(rp)
end

function check_restart!(rs::RandomRestart; tabu_length = nothing)
    return rand() ≤ rs.reset_percentage
end

# Tabu restart
mutable struct TabuRestart <: RestartStrategy
    index::Int
    tenure::Int
    limit::Int
    reset_percentage::Float64
end

function restart(strategy, ::Val{:tabu}; rp = 1.0, index = 1)
    limit = tenure(strategy, :tabu) - tenure(strategy, :pick)
    return TabuRestart(index, tenure(strategy, :tabu), limit, rp)
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

function oeis(n, b::Integer, ::Val{:A082850})
    m = log(b, n + 1)
    return isinteger(m) ? Int(m) : oeis(n - (b^floor(m) - 1), :A082850)
end
oeis(n, b::Integer, ::Val{:A182105}) = b^(oeis(n, :A082850) - 1)
oeis(n, ref::Symbol, b::Integer = 2) = oeis(n, b, Val(ref))
"The binary universal restart sequence, evaluated exactly with integer arithmetic."
function _universal_restart_length(n::Int)
    n > 0 || throw(ArgumentError("restart index must be positive"))
    while true
        power = one(Int) << (8 * sizeof(Int) - leading_zeros(n) - 1)
        n == power + (power - 1) && return power
        n -= power - 1
    end
end

restart(::Any, ::Val{:universal}) = RestartSequence(_universal_restart_length)

# Generic restart constructor
restart(tabu, strategy::Symbol) = restart(tabu, Val(strategy))

function restart_policy(trigger::RestartStrategy; reset_fraction::Real = 1.0,
        source::Symbol = :current)
    RestartPolicy(trigger; reset_fraction, source)
end

@testitem "Restart policies separate triggers from state perturbations" default_imports=false begin
    import LocalSearchSolvers as LS
    import Test: @test, @test_throws

    trigger = LS.restart(nothing, Val(:random); rp = 1.0)
    policy = LS.restart_policy(trigger; reset_fraction = 0.25, source = :best)
    @test LS.check_restart!(policy)
    @test LS.restart_fraction(policy) == 0.25
    @test LS.restart_source(policy) === :best
    @test_throws ArgumentError LS.restart_policy(trigger; reset_fraction = 1.1)
    @test_throws ArgumentError LS.restart_policy(trigger; source = :unknown)
end
