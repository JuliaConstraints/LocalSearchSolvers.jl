"""
    LeadSolver <: MetaSolver
Solver managed remotely by a MainSolver. Can manage its own set of local sub solvers.
"""
mutable struct LeadSolver <: MetaSolver
    meta_local_id::Tuple{Int, Int}
    model::_Model
    options::Options
    pool::Pool
    rc_report::RemoteChannel
    rc_sol::RemoteChannel
    rc_stop::RemoteChannel
    state::State
    strategies::MetaStrategy
    subs::Vector{_SubSolver}

    # Logger fields
    progress_tracker::Union{AbstractProgressTracker, Nothing}
    logger::AbstractLogger
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
        state(), strats, ss, progress_tracker, logger
    )
end

function _init!(s::LeadSolver)
    _init!(s, :meta)
    _init!(s, :local)
end

stop_while_loop(s::LeadSolver, ::Atomic{Bool}, ::Int, ::Float64) = isready(s.rc_stop)

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

    # Clear stop channel if ready
    isready(s.rc_stop) && take!(s.rc_stop)

    # Send solution pool to main solver
    put!(s.rc_sol, s.pool)

    # Mark as reported
    take!(s.rc_report)
end
