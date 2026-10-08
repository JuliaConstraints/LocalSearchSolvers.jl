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
# Bit values cannot refer back to the outer configuration. Keep the dictionary's
# existing deep-copy semantics and private indices and assignment storage.
function _owned_configuration(config::Configuration{T}) where T
    isbitstype(T) || return deepcopy(config)
    return Configuration(config.solution, config.value, deepcopy(config.values))
end
function pool(config::Configuration)
    best = 1
    configs = [_owned_configuration(config)]
    status = full_pool
    value = get_value(config)
    return _Pool(best, configs, status, value)
end
function pool!(s)
    has_solution(s) || _draw!(s)
    # Drawing changes the active configuration after `state(s)` computed its
    # aggregate cost. Synchronize all cost caches before snapshotting the pool.
    _compute!(s)
    _consider_configuration!(s, s.state.configuration)
end

is_empty(::EmptyPool) = true
is_empty(pool) = isempty(pool.configurations)
best_config(pool) = pool.configurations[pool.best]
best_value(pool) = pool.value
best_values(pool) = get_values(best_config(pool))

has_solution(::EmptyPool) = false
has_solution(pool::_Pool) = is_solution(best_config(pool))

# Published pools are immutable by convention: writers build owned snapshots and
# publish with release ordering; readers acquire an immutable, fully built snapshot.
# Readers never contend with the writer while checking a neighboring trajectory.
@inline _pool_snapshot(s) = @atomic :acquire s.pool
function _replace_pool!(s, value)
    lock(s.pool_lock) do
        @atomic :release s.pool = value
    end
    value
end
_solution_count(p) = is_empty(p) ? 0 : count(is_solution, p.configurations)
_solution_limit_reached(s) = _solution_count(_pool_snapshot(s)) >= get_option(s, Val(:solutions))
_same_assignment(a, b) = get_values(a) == get_values(b)
function _configuration_improves(current, candidate, capacity)
    isnan(get_value(candidate)) && return false
    is_empty(current) && return true
    feasible = is_solution(candidate)
    incumbent_feasible = has_solution(current)
    feasible != incumbent_feasible && return feasible
    capacity == 1 && return get_value(candidate) < best_value(current)
    duplicate = findfirst(c -> _same_assignment(c, candidate), current.configurations)
    duplicate !== nothing && return get_value(candidate) < get_value(current.configurations[duplicate])
    get_value(candidate) < best_value(current) && return true
    feasible && capacity > 1 && (length(current.configurations) < capacity ||
        get_value(candidate) < get_value(last(current.configurations)))
end
function _consider_configuration!(s, candidate)
    capacity = get_option(s, Val(:solutions))
    _configuration_improves(_pool_snapshot(s), candidate, capacity) || return false
    lock(s.pool_lock) do
        current = _pool_snapshot(s)
        _configuration_improves(current, candidate, capacity) || return false
        @ls_diagnostic s :summary :pool_replace reason=:admission proposed_score=get_value(candidate) proposed_values=collect(get_values(candidate))
        replacement = pool(candidate)
        if capacity > 1 && is_solution(candidate) && has_solution(current)
            append!(replacement.configurations, deepcopy(filter(c -> !_same_assignment(c, candidate), current.configurations)))
            sort!(replacement.configurations; by=get_value, alg=Base.Sort.MergeSort)
            resize!(replacement.configurations, min(capacity, length(replacement.configurations)))
            replacement.value = get_value(first(replacement.configurations))
        end
        @atomic :release s.pool = replacement
        return true
    end
end
function _pool_improves(current, incoming, capacity=1)
    !is_empty(incoming) && any(c -> _configuration_improves(current, c, capacity), incoming.configurations)
end
