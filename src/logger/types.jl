# Concrete type implementations for the logging and progress tracking system

"""
    ProgressTracker <: AbstractProgressTracker

Concrete implementation of progress tracker for solver progress.
"""
mutable struct ProgressTracker <: AbstractProgressTracker
    # Mode configuration
    mode::ProgressMode
    solver_id::String

    # Iteration tracking
    total_iterations::Union{Int, Nothing}
    current_iteration::Int

    # Time tracking
    start_time::Float64
    total_time::Union{Float64, Nothing}

    # Solution tracking
    has_valid_solution::Bool
    valid_solution_time::Float64
    valid_solution_iteration::Int

    # Error/objective tracking
    initial_error::Float64
    current_error::Float64
    best_objective::Union{Float64, Nothing}

    # Display state
    last_update_time::Float64
    bar_width::Int
    enabled::Bool
    last_formatted_bar::String

    # Constructor with defaults
    function ProgressTracker(;
            mode::ProgressMode = MIXED,
            solver_id::String = "Main",
            total_iterations::Union{Int, Nothing} = nothing,
            total_time::Union{Float64, Nothing} = nothing,
            bar_width::Int = 50
    )
        return new(
            mode,
            solver_id,
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
            time(),
            bar_width,
            true,
            ""
        )
    end
end

"""
    LoggerConfig

Configuration for the logging system.
"""
mutable struct LoggerConfig
    level::LogLevel
    destinations::Vector{Symbol}
    file_path::String
    log_mode::Symbol  # :full, :minimal, :silent

    # Progress update settings
    update_interval::Float64
    show_sub_progress::Bool
    show_remote_progress::Bool
    progress_layout::Symbol  # :stacked, :combined

    # Tracking state
    last_iter_logged::Dict{String, Int}
    last_time_logged::Dict{String, Float64}

    # Constructor with defaults
    function LoggerConfig(;
            level::LogLevel = INFO,
            destinations::Vector{Symbol} = [:console],
            file_path::String = "solver.log",
            log_mode::Symbol = :full,
            update_interval::Float64 = 0.1,
            show_sub_progress::Bool = true,
            show_remote_progress::Bool = true,
            progress_layout::Symbol = :stacked
    )
        return new(
            level,
            destinations,
            file_path,
            log_mode,
            update_interval,
            show_sub_progress,
            show_remote_progress,
            progress_layout,
            Dict{String, Int}(),
            Dict{String, Float64}()
        )
    end
end

"""
    Logger <: AbstractLogger

Concrete implementation of logger for solver logging.
"""
mutable struct Logger <: AbstractLogger
    config::LoggerConfig

    # Constructor with defaults
    function Logger(;
            level::LogLevel = INFO,
            destinations::Vector{Symbol} = [:console],
            file_path::String = "solver.log",
            log_mode::Symbol = :full,
            update_interval::Float64 = 0.1,
            show_sub_progress::Bool = true,
            show_remote_progress::Bool = true,
            progress_layout::Symbol = :stacked
    )
        config = LoggerConfig(
            level = level,
            destinations = destinations,
            file_path = file_path,
            log_mode = log_mode,
            update_interval = update_interval,
            show_sub_progress = show_sub_progress,
            show_remote_progress = show_remote_progress,
            progress_layout = progress_layout
        )
        return new(config)
    end

    # Constructor from existing config
    Logger(config::LoggerConfig) = new(config)
end
