"""
    LeadSolver <: MetaSolver
Solver managed remotely by a MainSolver. Can manage its own set of local sub solvers.
"""
mutable struct LeadSolver <: MetaSolver
    meta_local_id::Tuple{Int, Int}
    model::_Model
    options::Options
    @atomic pool::Pool
    rc_report::RemoteChannel
    rc_sol::RemoteChannel
    rc_stop::RemoteChannel
    state::State
    strategies::MetaStrategy
    subs::Vector{_SubSolver}

    # Logger fields
    progress_tracker::Union{AbstractProgressTracker, Nothing}
    logger::AbstractLogger
    pool_lock::ReentrantLock
    iterations::Int
end

function solver(
        mlid, model, options, pool, rc_report, rc_sol, rc_stop, strats, ::Val{:lead})
    l_options = deepcopy(options)
    set_option!(l_options, "print_level", :silent)
    ss = Vector{_SubSolver}()

    # Create progress tracker for lead solver
    lead_id = "Lead$(mlid[1])"
    progress_tracker = create_progress_tracker_from_options(l_options, lead_id)

    # Create logger for lead solver
    logger = create_logger_from_options(l_options)

    return LeadSolver(
        mlid, model, l_options, pool, rc_report, rc_sol, rc_stop,
        state(), strats, ss, progress_tracker, logger, ReentrantLock(), 0
    )
end

function _init!(s::LeadSolver)
    _init!(s, :meta)
    _init!(s, :local)
end

iterations(s::LeadSolver) = s.iterations
_iterations!(s::LeadSolver, value::Int) = s.iterations = value
function stop_while_loop(s::LeadSolver, stop::Atomic{Bool}, iter::Int, started::Float64)
    if isready(s.rc_stop)
        atomic_or!(stop, true)
        return false
    end
    _within_budget(s, stop, iter, started)
end

function _make_remote_solver(model, options, report, solutions, stop, strategies, worker, threads)
    # Incoming model is a serialized read lease from another process. Own the graph
    # locally and reset only its synchronization state, never its mathematical data.
    model=deepcopy(model)
    local_options = deepcopy(options)
    set_option!(local_options, "threads", min(threads, Threads.nthreads()))
    solver((worker, 0), model, local_options, pool(), report, solutions, stop, strategies, Val(:lead))
end

# Fetch only on the owning worker: fetching on the coordinator would serialize a copy.
function _run_remote_solver(handle::Future)
    s = fetch(handle)
    solve!(s)
    (pool=_pool_snapshot(s), iterations=iterations(s),
        sub_iterations=iterations.(s.subs), threads=1+length(s.subs),
        strategy_events=_strategy_run_records(s))
end

function remote_stop!(s::LeadSolver)
    # Send final progress update to main solver
    if !isnothing(s.progress_tracker)
        # Log stopping if in full mode
        if s.logger.config.log_mode == :full
            log_info(s.logger, "Lead solver stopping, has_solution=$(has_solution(s))")
        end

        # Send final progress update to main solver (worker 1)
        send_progress_update(s, 1)
    end

    # The completion future transports the final pool and any exception exactly once.
    @ls_diagnostic s :summary :remote_result_ready
    return nothing
end
