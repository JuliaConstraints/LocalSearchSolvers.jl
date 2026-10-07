"""
    _SubSolver <: AbstractSolver

An internal solver type called by MetaSolver when multithreading is enabled.

# Arguments:
- `id::Int`: subsolver id for debugging
- `model::Model`: a ref to the model of the main solver
- `state::_State`: a `deepcopy` of the main solver that evolves independently
- `options::Options`: a ref to the options of the main solver
"""
mutable struct _SubSolver <: AbstractSolver
    meta_local_id::Tuple{Int, Int}
    model::_Model
    options::Options
    @atomic pool::Pool
    state::State
    strategies::MetaStrategy
    iterations::Int

    # Logger fields
    progress_tracker::Union{AbstractProgressTracker, Nothing}
    logger::AbstractLogger
    pool_lock::ReentrantLock
end

function solver(mlid, model, options, pool, ::RemoteChannel,
        ::RemoteChannel, ::RemoteChannel, strats, ::Val{:sub})
    sub_options = deepcopy(options)
    set_option!(sub_options, "print_level", :silent)

    # Create progress tracker for sub-solver
    sub_id = "Sub$(mlid[2])"
    progress_tracker = create_progress_tracker_from_options(sub_options, sub_id)

    # Create logger for sub-solver
    logger = create_logger_from_options(sub_options)

    return _SubSolver(
        mlid, model, sub_options, deepcopy(pool), state(), strats, 0,
        progress_tracker, logger, ReentrantLock()
    )
end

_init!(s::_SubSolver) = _init!(s, :local)
iterations(s::_SubSolver) = s.iterations
_iterations!(s::_SubSolver, value::Int) = s.iterations = value

function stop_while_loop(s::_SubSolver, stop, iter::Int, start_time::Float64)
    return _within_budget(s, stop, iter, start_time)
end

function _within_budget(s, stop, iter::Int, start_time::Float64)
    stop[] && return false
    is_sat(s) && _solution_limit_reached(s) && return false
    iteration = get_option(s, Val(:iteration))
    time_limit = get_option(s, Val(:time_limit))
    iteration_reached = iter >= iteration[2]
    time_reached = time() - start_time > time_limit[2]
    solution = has_solution(s)
    stop_on_iteration = iteration[1] ? iteration_reached && solution : iteration_reached
    stop_on_time = time_limit[1] ? time_reached && solution : time_reached
    return !(stop_on_iteration || stop_on_time)
end
