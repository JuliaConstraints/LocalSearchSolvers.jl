# Progress tracking functionality

"""
    update_progress!(tracker::ProgressTracker;
                     iteration=nothing,
                     error=nothing,
                     objective=nothing,
                     has_valid_solution=nothing,
                     force_update=false)

Update the progress tracker with new solver state information.
"""
function update_progress!(tracker::ProgressTracker;
        iteration = nothing,
        error = nothing,
        objective = nothing,
        has_valid_solution = nothing,
        force_update = false
)
    current_time = time()

    # Update iteration if provided
    if !isnothing(iteration)
        tracker.current_iteration = iteration
    end

    # Update error if provided
    if !isnothing(error)
        if tracker.initial_error == Inf
            tracker.initial_error = error
        end
        tracker.current_error = error
    end

    # Update objective if provided
    if !isnothing(objective)
        if isnothing(tracker.best_objective) || objective < tracker.best_objective
            tracker.best_objective = objective
        end
    end

    # Update valid solution status if provided
    if !isnothing(has_valid_solution) && has_valid_solution && !tracker.has_valid_solution
        tracker.has_valid_solution = true
        tracker.valid_solution_time = current_time - tracker.start_time
        tracker.valid_solution_iteration = tracker.current_iteration
    end

    return current_time
end

"""
    should_display_update(tracker::ProgressTracker, config::LoggerConfig, current_time::Float64)

Determine if the progress display should be updated based on time interval and changes.
"""
function should_display_update(
        tracker::ProgressTracker, config::LoggerConfig, current_time::Float64)
    # Check if enough time has passed since last update
    time_to_update = (current_time - tracker.last_update_time) >= config.update_interval

    # For now, just use time-based updates
    # Could be extended with change-based logic (only update if progress changed significantly)
    return time_to_update
end

"""
    calculate_progress(tracker::ProgressTracker)

Calculate the current progress as a value between 0.0 and 1.0.
Returns -1.0 if progress cannot be determined.
"""
function calculate_progress(tracker::ProgressTracker)
    if tracker.mode == ITERATION && !isnothing(tracker.total_iterations)
        return min(1.0, tracker.current_iteration / tracker.total_iterations)
    elseif tracker.mode == TIME && !isnothing(tracker.total_time)
        elapsed = time() - tracker.start_time
        return min(1.0, elapsed / tracker.total_time)
    elseif tracker.mode == ERROR_REDUCTION && tracker.initial_error != Inf
        # Error reduction progress (0 = no reduction, 1 = error eliminated)
        error_reduction = 1.0 - (tracker.current_error / tracker.initial_error)
        return max(0.0, min(1.0, error_reduction))
    elseif tracker.mode == MIXED
        # Choose best available progress metric
        if !isnothing(tracker.total_iterations)
            return min(1.0, tracker.current_iteration / tracker.total_iterations)
        elseif !isnothing(tracker.total_time)
            elapsed = time() - tracker.start_time
            return min(1.0, elapsed / tracker.total_time)
        elseif tracker.initial_error != Inf
            error_reduction = 1.0 - (tracker.current_error / tracker.initial_error)
            return max(0.0, min(1.0, error_reduction))
        end
    end

    # Default: indeterminate progress
    return -1.0
end

"""
    reset_progress!(tracker::ProgressTracker)

Reset the progress tracker to its initial state.
"""
function reset_progress!(tracker::ProgressTracker)
    tracker.current_iteration = 0
    tracker.start_time = time()
    tracker.has_valid_solution = false
    tracker.valid_solution_time = 0.0
    tracker.valid_solution_iteration = 0
    tracker.initial_error = Inf
    tracker.current_error = Inf
    tracker.best_objective = nothing
    tracker.last_update_time = time()
    tracker.last_formatted_bar = ""
end

"""
    enable_progress!(tracker::ProgressTracker, enabled::Bool = true)

Enable or disable the progress tracker.
"""
function enable_progress!(tracker::ProgressTracker, enabled::Bool = true)
    tracker.enabled = enabled
end

"""
    set_progress_mode!(tracker::ProgressTracker, mode::ProgressMode)

Set the progress tracking mode.
"""
function set_progress_mode!(tracker::ProgressTracker, mode::ProgressMode)
    tracker.mode = mode
end

"""
    set_progress_mode!(tracker::ProgressTracker, mode::Symbol)

Set the progress tracking mode using a symbol.
"""
function set_progress_mode!(tracker::ProgressTracker, mode::Symbol)
    tracker.mode = symbol_to_progress_mode(mode)
end

# Export progress tracking functions
export update_progress!, reset_progress!, enable_progress!
export set_progress_mode!, calculate_progress
