# Terminal display functionality for progress bars

"""
    format_progress_bar(tracker::AbstractProgressTracker, logger::AbstractLogger)

Format a progress bar string based on the current state of the tracker.
"""
function format_progress_bar(tracker::AbstractProgressTracker, logger::AbstractLogger)
    # Get config from logger
    config = logger.config
    if !tracker.enabled || tracker.mode == NONE
        return ""
    end

    current_time = time()
    elapsed = current_time - tracker.start_time
    elapsed_str = @sprintf("%.1fs", elapsed)

    # Calculate progress
    progress = calculate_progress(tracker)

    # Indeterminate progress bar (no measurable progress)
    if progress < 0
        idx = Int(round(current_time * 10)) % tracker.bar_width
        chars = fill(' ', tracker.bar_width)
        chars[idx + 1] = '█'

        bar = "[" * String(chars) * "]"

        if tracker.has_valid_solution
            valid_info = " [Valid: $(@sprintf("%.1fs", tracker.valid_solution_time))]"
        else
            valid_info = ""
        end

        return "[$(tracker.solver_id)] $(bar) Searching$(valid_info) ($(elapsed_str))"
    end

    # Standard progress bar
    filled_width = Int(round(tracker.bar_width * progress))
    filled = "█"^filled_width
    empty = "░"^(tracker.bar_width - filled_width)

    percent = @sprintf("%.1f%%", progress*100)
    bar = "[$(filled)$(empty)] $(percent)"

    # Add context-specific information
    if tracker.mode == ITERATION ||
       (tracker.mode == MIXED && !isnothing(tracker.total_iterations))
        iter_info = "Iter: $(tracker.current_iteration)/$(tracker.total_iterations)"

        if tracker.has_valid_solution
            valid_info = " [Valid: iter $(tracker.valid_solution_iteration)]"
        else
            valid_info = ""
        end

        return "[$(tracker.solver_id)] $(bar) $(iter_info)$(valid_info) ($(elapsed_str))"
    elseif tracker.mode == TIME || (tracker.mode == MIXED && !isnothing(tracker.total_time))
        time_info = "Time: $(elapsed_str)/$(@sprintf("%.1fs", tracker.total_time))"
        remaining = @sprintf("%.1fs", max(0.0, tracker.total_time - elapsed))

        if tracker.has_valid_solution
            valid_info = " [Valid: $(@sprintf("%.1fs", tracker.valid_solution_time))]"
        else
            valid_info = ""
        end

        return "[$(tracker.solver_id)] $(bar) $(time_info)$(valid_info) ($(remaining) remaining)"
    elseif tracker.mode == ERROR_REDUCTION ||
           (tracker.mode == MIXED && tracker.initial_error != Inf)
        error_info = "Error: $(@sprintf("%.2e", tracker.current_error)) ($(@sprintf("%.1f%%", (1.0 - progress) * 100)) of initial)"

        if tracker.has_valid_solution
            valid_info = " [Valid]"
        else
            valid_info = ""
        end

        return "[$(tracker.solver_id)] $(bar) $(error_info)$(valid_info) ($(elapsed_str))"
    elseif tracker.mode == OBJECTIVE && !isnothing(tracker.best_objective)
        obj_info = "Objective: $(@sprintf("%.6g", tracker.best_objective))"

        if tracker.has_valid_solution
            valid_info = " [Valid]"
        else
            valid_info = ""
        end

        return "[$(tracker.solver_id)] $(bar) $(obj_info)$(valid_info) ($(elapsed_str))"
    end

    # Generic progress bar
    return "[$(tracker.solver_id)] $(bar) ($(elapsed_str))"
end

"""
    display_progress!(tracker::AbstractProgressTracker, logger::AbstractLogger; force_update=false)

Update the terminal display with the current progress.
"""
function display_progress!(
        tracker::AbstractProgressTracker, logger::AbstractLogger; force_update = false)
    # Get config from logger
    config = logger.config
    # Skip if progress display is disabled
    if config.log_mode == :silent || !tracker.enabled
        return
    end

    current_time = time()

    # Check if we should update the display
    should_update = force_update || should_display_update(tracker, config, current_time)

    if should_update && :console in config.destinations
        new_bar = format_progress_bar(tracker, logger)

        # Only update if the bar has changed
        if new_bar != tracker.last_formatted_bar
            # Clear the previous bar
            if !isempty(tracker.last_formatted_bar)
                print("\r" * " "^length(tracker.last_formatted_bar) * "\r")
            end

            # Print the new bar
            print("\r$(new_bar)")
            flush(stdout)

            tracker.last_formatted_bar = new_bar
            tracker.last_update_time = current_time
        end
    end
end

"""
    finalize_progress!(tracker::AbstractProgressTracker, logger::AbstractLogger)

Display the final progress state and add a newline.
"""
function finalize_progress!(tracker::AbstractProgressTracker, logger::AbstractLogger)
    # Get config from logger
    config = logger.config
    if !tracker.enabled || config.log_mode == :silent
        return
    end

    # Set to 100% completion if we have a total
    if !isnothing(tracker.total_iterations)
        tracker.current_iteration = tracker.total_iterations
    end

    # Force update the display
    display_progress!(tracker, logger, force_update = true)

    # Add a newline after the final progress bar
    if !isempty(tracker.last_formatted_bar)
        println()
    end

    # Reset the last formatted bar
    tracker.last_formatted_bar = ""
end

"""
    display_multi_progress!(trackers::Vector{<:AbstractProgressTracker}, logger::AbstractLogger)

Display multiple progress bars for different solvers.
"""
function display_multi_progress!(
        trackers::Vector{<:AbstractProgressTracker}, logger::AbstractLogger)
    # Get config from logger
    config = logger.config
    # Skip if progress display is disabled
    if config.log_mode == :silent
        return
    end

    # Skip if no trackers
    if isempty(trackers)
        return
    end

    # Clear all previous bars
    for tracker in trackers
        if !isempty(tracker.last_formatted_bar)
            print("\r" * " "^length(tracker.last_formatted_bar) * "\r")
            println()
        end
    end

    # Move cursor back up
    print("\e[$(length(trackers))A")

    # Print all bars
    for tracker in trackers
        new_bar = format_progress_bar(tracker, logger)
        print("\r$(new_bar)")
        println()
        tracker.last_formatted_bar = new_bar
        tracker.last_update_time = time()
    end

    flush(stdout)
end

"""
    finalize_multi_progress!(trackers::Vector{<:AbstractProgressTracker}, logger::AbstractLogger)

Finalize multiple progress bars.
"""
function finalize_multi_progress!(
        trackers::Vector{<:AbstractProgressTracker}, logger::AbstractLogger)
    # Get config from logger
    config = logger.config
    # Skip if progress display is disabled
    if config.log_mode == :silent
        return
    end

    # Skip if no trackers
    if isempty(trackers)
        return
    end

    # Set all trackers to 100% completion if they have a total
    for tracker in trackers
        if !isnothing(tracker.total_iterations)
            tracker.current_iteration = tracker.total_iterations
        end
    end

    # Display final state
    display_multi_progress!(trackers, logger)

    # Reset all formatted bars
    for tracker in trackers
        tracker.last_formatted_bar = ""
    end
end

# Add compatibility functions for backward compatibility
function format_progress_bar(tracker::AbstractProgressTracker, config::LoggerConfig)
    format_progress_bar(tracker, Logger(config))
end
function display_progress!(
        tracker::AbstractProgressTracker, config::LoggerConfig; force_update = false)
    display_progress!(tracker, Logger(config), force_update = force_update)
end
function finalize_progress!(tracker::AbstractProgressTracker, config::LoggerConfig)
    finalize_progress!(tracker, Logger(config))
end
function display_multi_progress!(
        trackers::Vector{<:AbstractProgressTracker}, config::LoggerConfig)
    display_multi_progress!(trackers, Logger(config))
end
function finalize_multi_progress!(
        trackers::Vector{<:AbstractProgressTracker}, config::LoggerConfig)
    finalize_multi_progress!(trackers, Logger(config))
end

# Export display functions
export display_progress!, finalize_progress!
export display_multi_progress!, finalize_multi_progress!
export format_progress_bar
