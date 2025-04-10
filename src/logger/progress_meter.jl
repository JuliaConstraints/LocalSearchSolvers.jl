# ProgressMeter-based implementation of progress tracking

"""
    ProgressMeterTracker <: AbstractProgressTracker

Concrete implementation of progress tracker using ProgressMeter.jl for persistent display.
"""
mutable struct ProgressMeterTracker <: AbstractProgressTracker
    # Mode configuration
    mode::ProgressMode
    solver_id::String

    # ProgressMeter instances
    progress::Union{Progress, ProgressThresh, ProgressUnknown, Nothing}

    # Tracking state (similar to current ProgressTracker)
    total_iterations::Union{Int, Nothing}
    current_iteration::Int
    start_time::Float64
    total_time::Union{Float64, Nothing}
    has_valid_solution::Bool
    valid_solution_time::Float64
    valid_solution_iteration::Int
    initial_error::Float64
    current_error::Float64
    best_objective::Union{Float64, Nothing}

    # Display settings
    enabled::Bool
    bar_width::Int
    bar_glyphs::BarGlyphs
    update_interval::Float64

    # Constructor
    function ProgressMeterTracker(;
            mode::ProgressMode = MIXED,
            solver_id::String = "Main",
            total_iterations::Union{Int, Nothing} = nothing,
            total_time::Union{Float64, Nothing} = nothing,
            bar_width::Int = 50,
            bar_glyphs::Union{BarGlyphs, Nothing} = nothing,
            update_interval::Float64 = 0.1
    )
        # Create appropriate ProgressMeter instance based on mode
        progress = create_progress_meter(
            mode, total_iterations, total_time, solver_id,
            bar_width, bar_glyphs, update_interval
        )

        return new(
            mode,
            solver_id,
            progress,
            total_iterations,
            0,
            time(),
            total_time,
            false,
            0.0,
            0,
            Inf,
            Inf,
            nothing,
            true,
            bar_width,
            bar_glyphs === nothing ?
            BarGlyphs('|', '█', ['▏', '▎', '▍', '▌', '▋', '▊', '▉'], ' ', '|') : bar_glyphs,
            update_interval
        )
    end
end

"""
    create_progress_meter(mode, total_iterations, total_time, solver_id, bar_width, bar_glyphs, update_interval)

Helper function to create appropriate ProgressMeter instance based on mode.
"""
function create_progress_meter(
        mode, total_iterations, total_time, solver_id, bar_width, bar_glyphs, update_interval)
    if mode == NONE
        return nothing
    end

    # Set default bar glyphs if not provided
    if bar_glyphs === nothing
        bar_glyphs = BarGlyphs('|', '█', ['▏', '▎', '▍', '▌', '▋', '▊', '▉'], ' ', '|')
    end

    # Create progress meter based on mode
    if mode == ITERATION && !isnothing(total_iterations)
        return Progress(
            total_iterations;
            dt = update_interval,
            desc = "[$solver_id] ",
            showspeed = true
        )
    elseif mode == TIME && !isnothing(total_time)
        # For time-based progress, we'll use a threshold-based approach
        return ProgressThresh(
            total_time;
            dt = update_interval,
            desc = "[$solver_id] "
        )
    elseif (mode == ERROR_REDUCTION || mode == OBJECTIVE) && !isnothing(total_iterations)
        # For error/objective-based progress with known iterations
        return Progress(
            total_iterations;
            dt = update_interval,
            desc = "[$solver_id] "
        )
    elseif mode == MIXED || mode == SMART
        # For mixed mode, choose based on available limits
        if !isnothing(total_iterations)
            return Progress(
                total_iterations;
                dt = update_interval,
                desc = "[$solver_id] ",
                showspeed = true
            )
        elseif !isnothing(total_time)
            return ProgressThresh(
                total_time;
                dt = update_interval,
                desc = "[$solver_id] "
            )
        end
    end

    # Default to ProgressUnknown for indeterminate progress
    return ProgressUnknown(
        dt = update_interval,
        desc = "[$solver_id] ",
        spinner = true
    )
end

"""
    generate_showvalues(tracker::ProgressMeterTracker)

Generate showvalues for additional information display.
"""
function generate_showvalues(tracker::ProgressMeterTracker)
    values = []

    # Add time information
    elapsed = time() - tracker.start_time
    push!(values, ("Time", @sprintf("%.1fs", elapsed)))

    # Add iteration information if available
    if !isnothing(tracker.total_iterations)
        push!(values,
            ("Iteration", "$(tracker.current_iteration)/$(tracker.total_iterations)"))
    end

    # Add error information if available
    if tracker.initial_error != Inf && tracker.initial_error != tracker.current_error
        error_reduction = 100 * (1.0 - (tracker.current_error / tracker.initial_error))
        push!(values, ("Error reduction", @sprintf("%.1f%%", error_reduction)))
    end

    # Add objective information if available
    if !isnothing(tracker.best_objective)
        push!(values, ("Best objective", @sprintf("%.6g", tracker.best_objective)))
    end

    # Add solution status
    if tracker.has_valid_solution
        push!(
            values, ("Valid solution", "Yes (at $(tracker.valid_solution_iteration) iter)"))
    end

    return values
end

# Interface implementation

"""
    update_progress!(tracker::ProgressMeterTracker;
                     iteration=nothing,
                     error=nothing,
                     objective=nothing,
                     has_valid_solution=nothing,
                     force_update=false)

Update the progress tracker with new solver state information.
"""
function update_progress!(tracker::ProgressMeterTracker;
        iteration = nothing,
        error = nothing,
        objective = nothing,
        has_valid_solution = nothing,
        force_update = false
)
    current_time = time()

    # Skip if disabled
    if !tracker.enabled
        return current_time
    end

    # Update tracking state
    if !isnothing(iteration)
        tracker.current_iteration = iteration
    end

    if !isnothing(error)
        if tracker.initial_error == Inf
            tracker.initial_error = error
        end
        tracker.current_error = error
    end

    if !isnothing(objective)
        if isnothing(tracker.best_objective) || objective < tracker.best_objective
            tracker.best_objective = objective
        end
    end

    if !isnothing(has_valid_solution) && has_valid_solution && !tracker.has_valid_solution
        tracker.has_valid_solution = true
        tracker.valid_solution_time = current_time - tracker.start_time
        tracker.valid_solution_iteration = tracker.current_iteration
    end

    # Update ProgressMeter based on mode
    if !isnothing(tracker.progress)
        # Generate showvalues with additional information
        showvalues = generate_showvalues(tracker)

        if tracker.mode == ITERATION
            # For iteration-based progress, use next! or update!
            if !isnothing(iteration)
                update!(tracker.progress, iteration; showvalues = showvalues)
            end
        elseif tracker.mode == TIME
            # For time-based progress, update with elapsed time
            elapsed = current_time - tracker.start_time
            update!(tracker.progress, elapsed; showvalues = showvalues)
        elseif tracker.mode == ERROR_REDUCTION && !isnothing(error)
            # For error-based progress, update with error reduction
            if tracker.initial_error != Inf
                error_reduction = 1.0 - (error / tracker.initial_error)
                update!(tracker.progress, error_reduction * tracker.total_iterations;
                    showvalues = showvalues)
            end
        elseif tracker.mode == OBJECTIVE && !isnothing(objective) &&
               !isnothing(tracker.best_objective)
            # For objective-based progress, just update with current iteration
            if !isnothing(iteration) && !isnothing(tracker.total_iterations)
                update!(tracker.progress, iteration; showvalues = showvalues)
            end
        elseif tracker.mode == MIXED || tracker.mode == SMART
            # Choose best available metric
            if !isnothing(iteration) && !isnothing(tracker.total_iterations)
                update!(tracker.progress, iteration; showvalues = showvalues)
            elseif !isnothing(tracker.total_time)
                elapsed = current_time - tracker.start_time
                update!(tracker.progress, elapsed; showvalues = showvalues)
            elseif tracker.mode == MIXED && tracker.initial_error != Inf &&
                   !isnothing(error)
                error_reduction = 1.0 - (error / tracker.initial_error)
                next!(tracker.progress; showvalues = showvalues)
            else
                # For indeterminate progress, just call next!
                next!(tracker.progress; showvalues = showvalues)
            end
        else
            # For indeterminate progress, just call next!
            next!(tracker.progress; showvalues = showvalues)
        end
    end

    return current_time
end

"""
    display_progress!(tracker::ProgressMeterTracker, logger::AbstractLogger; force_update = false)

Update the terminal display with the current progress.
ProgressMeter.jl handles the display automatically when next!/update! is called.
This function is kept for interface compatibility.
"""
function display_progress!(
        tracker::ProgressMeterTracker, logger::AbstractLogger; force_update = false)
    # ProgressMeter.jl handles the display automatically when next!/update! is called
    # This function is kept for interface compatibility
    if force_update && !isnothing(tracker.progress) && tracker.enabled
        # Generate showvalues with additional information
        showvalues = generate_showvalues(tracker)

        if isa(tracker.progress, Progress)
            update!(tracker.progress, tracker.current_iteration; showvalues = showvalues)
        elseif isa(tracker.progress, ProgressThresh)
            elapsed = time() - tracker.start_time
            update!(tracker.progress, elapsed; showvalues = showvalues)
        else
            next!(tracker.progress; showvalues = showvalues)
        end
    end
end

"""
    finalize_progress!(tracker::ProgressMeterTracker, logger::AbstractLogger)

Display the final progress state and add a newline.
"""
function finalize_progress!(tracker::ProgressMeterTracker, logger::AbstractLogger)
    if !isnothing(tracker.progress) && tracker.enabled
        # Set to 100% completion if we have a total
        if !isnothing(tracker.total_iterations) && isa(tracker.progress, Progress)
            update!(tracker.progress, tracker.total_iterations)
        end

        # Finalize the progress display
        finish!(tracker.progress)
    end
end

"""
    reset_progress!(tracker::ProgressMeterTracker)

Reset the progress tracker to its initial state.
"""
function reset_progress!(tracker::ProgressMeterTracker)
    tracker.current_iteration = 0
    tracker.start_time = time()
    tracker.has_valid_solution = false
    tracker.valid_solution_time = 0.0
    tracker.valid_solution_iteration = 0
    tracker.initial_error = Inf
    tracker.current_error = Inf
    tracker.best_objective = nothing

    # Recreate the progress meter
    tracker.progress = create_progress_meter(
        tracker.mode,
        tracker.total_iterations,
        tracker.total_time,
        tracker.solver_id,
        tracker.bar_width,
        tracker.bar_glyphs,
        tracker.update_interval
    )
end

"""
    enable_progress!(tracker::ProgressMeterTracker, enabled::Bool = true)

Enable or disable the progress tracker.
"""
function enable_progress!(tracker::ProgressMeterTracker, enabled::Bool = true)
    tracker.enabled = enabled
end

"""
    set_progress_mode!(tracker::ProgressMeterTracker, mode::ProgressMode)

Set the progress tracking mode.
"""
function set_progress_mode!(tracker::ProgressMeterTracker, mode::ProgressMode)
    if tracker.mode != mode
        tracker.mode = mode

        # Recreate the progress meter with the new mode
        tracker.progress = create_progress_meter(
            mode,
            tracker.total_iterations,
            tracker.total_time,
            tracker.solver_id,
            tracker.bar_width,
            tracker.bar_glyphs,
            tracker.update_interval
        )
    end
end

"""
    set_progress_mode!(tracker::ProgressMeterTracker, mode::Symbol)

Set the progress tracking mode using a symbol.
"""
function set_progress_mode!(tracker::ProgressMeterTracker, mode::Symbol)
    set_progress_mode!(tracker, symbol_to_progress_mode(mode))
end

"""
    calculate_progress(tracker::ProgressMeterTracker)

Calculate the current progress as a value between 0.0 and 1.0.
Returns -1.0 if progress cannot be determined.
"""
function calculate_progress(tracker::ProgressMeterTracker)
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
    elseif tracker.mode == SMART
        # Only show progress for time/iteration when limits are set
        if !isnothing(tracker.total_iterations)
            return min(1.0, tracker.current_iteration / tracker.total_iterations)
        elseif !isnothing(tracker.total_time)
            elapsed = time() - tracker.start_time
            return min(1.0, elapsed / tracker.total_time)
        end
        # No progress display if no limits are set
        return -1.0
    end

    # Default: indeterminate progress
    return -1.0
end

# Export the ProgressMeterTracker
export ProgressMeterTracker
