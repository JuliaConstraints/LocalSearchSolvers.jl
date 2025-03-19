# Distributed logging support for Phase 4 implementation

using Distributed

"""
    ProgressUpdate

Structure to hold progress update information for remote communication.
"""
struct ProgressUpdate
    worker_id::Int
    solver_id::String
    iteration::Int
    error::Float64
    has_valid_solution::Bool
    valid_solution_time::Float64
    valid_solution_iteration::Int
    best_objective::Union{Float64, Nothing}
    timestamp::Float64
end

"""
    sync_progress!(main_tracker::AbstractProgressTracker, remote_tracker::AbstractProgressTracker)

Synchronize progress information from a remote tracker to the main tracker.
"""
function sync_progress!(
        main_tracker::AbstractProgressTracker, remote_tracker::AbstractProgressTracker)
    # Update valid solution status
    if remote_tracker.has_valid_solution && !main_tracker.has_valid_solution
        main_tracker.has_valid_solution = true
        main_tracker.valid_solution_time = remote_tracker.valid_solution_time
        main_tracker.valid_solution_iteration = remote_tracker.valid_solution_iteration
    end

    # Update best objective if remote has a better one
    if !isnothing(remote_tracker.best_objective) &&
       (isnothing(main_tracker.best_objective) ||
        remote_tracker.best_objective < main_tracker.best_objective)
        main_tracker.best_objective = remote_tracker.best_objective
    end

    # Update error if remote has a lower one
    if remote_tracker.current_error < main_tracker.current_error
        main_tracker.current_error = remote_tracker.current_error
    end

    # Update iteration if remote has a higher one and we're using the same total
    if !isnothing(main_tracker.total_iterations) &&
       !isnothing(remote_tracker.total_iterations) &&
       main_tracker.total_iterations == remote_tracker.total_iterations &&
       remote_tracker.current_iteration > main_tracker.current_iteration
        main_tracker.current_iteration = remote_tracker.current_iteration
    end
end

"""
    collect_remote_trackers(main_solver::AbstractSolver)

Collect progress trackers from remote solvers.
"""
function collect_remote_trackers(main_solver)
    trackers = AbstractProgressTracker[]

    # Skip if no remote solvers or progress tracking disabled
    if !hasfield(typeof(main_solver), :remotes) ||
       isnothing(main_solver.progress_tracker) ||
       !get_option(main_solver, "show_remote_progress", true)
        return trackers
    end

    # Collect trackers from remote solvers
    for (worker_id, remote_solver_future) in main_solver.remotes
        try
            # Get remote tracker state
            remote_tracker_state = remotecall_fetch(
                s -> begin
                    if !isnothing(s.progress_tracker)
                        (
                            s.progress_tracker.mode,
                            s.progress_tracker.solver_id,
                            s.progress_tracker.total_iterations,
                            s.progress_tracker.current_iteration,
                            s.progress_tracker.start_time,
                            s.progress_tracker.total_time,
                            s.progress_tracker.has_valid_solution,
                            s.progress_tracker.valid_solution_time,
                            s.progress_tracker.valid_solution_iteration,
                            s.progress_tracker.initial_error,
                            s.progress_tracker.current_error,
                            s.progress_tracker.best_objective,
                            time() - s.progress_tracker.start_time
                        )
                    else
                        nothing
                    end
                end,
                worker_id,
                fetch(remote_solver_future)
            )

            # Skip if no tracker
            isnothing(remote_tracker_state) && continue

            # Create a local copy of the remote tracker
            mode, solver_id, total_iterations, current_iteration,
            start_time, total_time, has_valid_solution,
            valid_solution_time, valid_solution_iteration,
            initial_error, current_error, best_objective, elapsed = remote_tracker_state

            tracker = ProgressTracker(
                mode = mode,
                solver_id = solver_id,
                total_iterations = total_iterations,
                total_time = total_time
            )

            tracker.current_iteration = current_iteration
            tracker.start_time = time() - elapsed
            tracker.has_valid_solution = has_valid_solution
            tracker.valid_solution_time = valid_solution_time
            tracker.valid_solution_iteration = valid_solution_iteration
            tracker.initial_error = initial_error
            tracker.current_error = current_error
            tracker.best_objective = best_objective

            push!(trackers, tracker)
        catch e
            # Log error but continue with other remote solvers
            @warn "Error collecting progress from worker $worker_id: $e"
        end
    end

    return trackers
end

"""
    update_remote_progress!(main_solver::AbstractSolver)

Update the main solver's progress with information from remote solvers.
"""
function update_remote_progress!(main_solver)
    # Skip if no progress tracking or remote progress disabled
    if isnothing(main_solver.progress_tracker) ||
       !get_option(main_solver, "show_remote_progress", true)
        return
    end

    # Collect remote trackers
    remote_trackers = collect_remote_trackers(main_solver)

    # Skip if no remote trackers
    isempty(remote_trackers) && return

    # Sync progress from remote trackers to main tracker
    for remote_tracker in remote_trackers
        sync_progress!(main_solver.progress_tracker, remote_tracker)
    end

    # Display multi-progress if enabled
    if get_option(main_solver, "progress_layout", :stacked) == :stacked
        # Create a vector with main tracker first, then remote trackers
        all_trackers = AbstractProgressTracker[main_solver.progress_tracker]
        append!(all_trackers, remote_trackers)

        # Display all progress bars
        display_multi_progress!(all_trackers, main_solver.logger)
    else
        # Just update the main tracker display
        display_progress!(main_solver.progress_tracker, main_solver.logger)
    end
end

"""
    log_remote_message(logger::AbstractLogger, worker_id::Int, level::LogLevel, message::String)

Log a message from a remote worker.
"""
function log_remote_message(
        logger::AbstractLogger, worker_id::Int, level::LogLevel, message::String)
    # Prepend worker ID to message
    worker_message = "[Worker $worker_id] $message"

    # Log using standard logging function
    log_message(logger, level, worker_message)
end

"""
    log_remote_message(config::LoggerConfig, worker_id::Int, level::LogLevel, message::String)

Log a message from a remote worker (compatibility function).
"""
function log_remote_message(
        config::LoggerConfig, worker_id::Int, level::LogLevel, message::String)
    log_remote_message(Logger(config), worker_id, level, message)
end

"""
    send_progress_update(solver::AbstractSolver, main_worker_id::Int)

Send a progress update from a remote solver to the main solver.
"""
function send_progress_update(solver::AbstractSolver, main_worker_id::Int)
    # Skip if no progress tracking
    isnothing(solver.progress_tracker) && return

    # Create progress update
    update = ProgressUpdate(
        myid(),
        solver.progress_tracker.solver_id,
        solver.progress_tracker.current_iteration,
        solver.progress_tracker.current_error,
        solver.progress_tracker.has_valid_solution,
        solver.progress_tracker.valid_solution_time,
        solver.progress_tracker.valid_solution_iteration,
        solver.progress_tracker.best_objective,
        time()
    )

    # Send update to main solver
    try
        remote_do(
            (update) -> begin
                # Find the main solver
                for s in Main.MAIN_SOLVERS
                    if s isa MainSolver
                        # Apply the update
                        if !isnothing(s.progress_tracker)
                            # Create a temporary tracker with the update info
                            temp_tracker = ProgressTracker(
                                solver_id = update.solver_id,
                                mode = s.progress_tracker.mode
                            )
                            temp_tracker.current_iteration = update.iteration
                            temp_tracker.current_error = update.error
                            temp_tracker.has_valid_solution = update.has_valid_solution
                            temp_tracker.valid_solution_time = update.valid_solution_time
                            temp_tracker.valid_solution_iteration = update.valid_solution_iteration
                            temp_tracker.best_objective = update.best_objective

                            # Sync the update
                            sync_progress!(s.progress_tracker, temp_tracker)

                            # Log the update if in full mode
                            if s.logger.config.log_mode == :full
                                log_remote_message(
                                    s.logger,
                                    update.worker_id,
                                    INFO,
                                    "Progress update from $(update.solver_id): iteration=$(update.iteration), error=$(update.error)"
                                )
                            end
                        end
                        break
                    end
                end
            end,
            main_worker_id,
            update
        )
    catch e
        # Log error but continue
        @warn "Error sending progress update to main worker: $e"
    end
end

"""
    initialize_distributed_logging()

Initialize distributed logging system.
"""
function initialize_distributed_logging()
    # Create a global registry for main solvers if it doesn't exist
    if !isdefined(Main, :MAIN_SOLVERS)
        @eval Main begin
            const MAIN_SOLVERS = Set{Any}()
        end
    end
end

"""
    register_main_solver(solver::AbstractSolver)

Register a main solver for distributed logging.
"""
function register_main_solver(solver::AbstractSolver)
    # Initialize distributed logging if needed
    initialize_distributed_logging()

    # Add solver to registry
    push!(Main.MAIN_SOLVERS, solver)
end

"""
    unregister_main_solver(solver::AbstractSolver)

Unregister a main solver from distributed logging.
"""
function unregister_main_solver(solver::AbstractSolver)
    # Remove solver from registry if it exists
    if isdefined(Main, :MAIN_SOLVERS)
        delete!(Main.MAIN_SOLVERS, solver)
    end
end

# Export distributed logging functions
export sync_progress!, collect_remote_trackers, log_remote_message
export update_remote_progress!, send_progress_update
export initialize_distributed_logging, register_main_solver, unregister_main_solver
