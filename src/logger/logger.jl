# Implementation of the logger interface

"""
    log_message(logger::Logger, level::LogLevel, message::String)

Log a message with the specified level if it meets the configured log level.
"""
function log_message(logger::Logger, level::LogLevel, message::String)
    # Get config from logger
    config = logger.config
    # Skip if log level is too low
    if level > config.level || config.log_mode == :silent
        return
    end

    # Format the message with timestamp and level
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    level_str = uppercase(string(level))
    formatted_msg = "[$timestamp][$level_str] $message"

    # Output to configured destinations
    if :console in config.destinations && config.log_mode == :full
        println(formatted_msg)
    end

    if :file in config.destinations
        open(config.file_path, "a") do io
            println(io, formatted_msg)
        end
    end
end

"""
    log_error(logger::Logger, message::String)

Log an error message.
"""
function log_error(logger::Logger, message::String)
    log_message(logger, LOG_ERROR, message)
end

"""
    log_warn(logger::Logger, message::String)

Log a warning message.
"""
function log_warn(logger::Logger, message::String)
    log_message(logger, WARN, message)
end

"""
    log_info(logger::Logger, message::String)

Log an informational message.
"""
function log_info(logger::Logger, message::String)
    log_message(logger, INFO, message)
end

"""
    log_debug(logger::Logger, message::String)

Log a debug message.
"""
function log_debug(logger::Logger, message::String)
    log_message(logger, DEBUG, message)
end

# Implement the interface functions for backward compatibility
function log_message(config::LoggerConfig, level::LogLevel, message::String)
    log_message(Logger(config), level, message)
end
log_error(config::LoggerConfig, message::String) = log_error(Logger(config), message)
log_warn(config::LoggerConfig, message::String) = log_warn(Logger(config), message)
log_info(config::LoggerConfig, message::String) = log_info(Logger(config), message)
log_debug(config::LoggerConfig, message::String) = log_debug(Logger(config), message)

"""
    reset_logger!(logger::Logger)

Reset the logger state and clear the log file if it exists.
"""
function reset_logger!(logger::Logger)
    # Get config from logger
    config = logger.config
    # Clear tracking state
    empty!(config.last_iter_logged)
    empty!(config.last_time_logged)

    # Clear log file if logging to file
    if :file in config.destinations
        open(config.file_path, "w") do io
            println(io, "# Solver log started at $(now())")
        end
    end
end

"""
    should_log_iteration(config::LoggerConfig, solver_id::String, iteration::Int)

Determine if an iteration should be logged based on frequency settings.
"""
function should_log_iteration(config::LoggerConfig, solver_id::String, iteration::Int)
    # Get the last logged iteration for this solver
    last_iter = get(config.last_iter_logged, solver_id, 0)

    # Determine log frequency based on iteration count
    # Log more frequently at the beginning, less frequently as iterations increase
    log_freq = if iteration < 100
        1  # Log every iteration for the first 100
    elseif iteration < 1000
        10  # Log every 10th iteration from 100-1000
    elseif iteration < 10000
        100  # Log every 100th iteration from 1000-10000
    else
        1000  # Log every 1000th iteration after 10000
    end

    # Check if we should log this iteration
    should_log = (iteration - last_iter) >= log_freq

    # Update last logged iteration if we're logging
    if should_log
        config.last_iter_logged[solver_id] = iteration
    end

    return should_log
end

"""
    should_log_time(config::LoggerConfig, solver_id::String)

Determine if enough time has passed to log a time-based update.
"""
function should_log_time(config::LoggerConfig, solver_id::String)
    current_time = time()
    last_time = get(config.last_time_logged, solver_id, 0.0)

    # Check if enough time has passed since the last log
    should_log = (current_time - last_time) >= config.update_interval

    # Update last logged time if we're logging
    if should_log
        config.last_time_logged[solver_id] = current_time
    end

    return should_log
end

"""
    log_solver_state(logger::Logger, solver_id::String, iteration::Int, error::Float64,
                    has_solution::Bool, objective_value::Union{Float64, Nothing}=nothing)

Log the current state of a solver if it meets the logging criteria.
"""
function log_solver_state(
        logger::Logger,
        solver_id::String,
        iteration::Int,
        error::Float64,
        has_solution::Bool,
        objective_value::Union{Float64, Nothing} = nothing
)
    # Get config from logger
    config = logger.config

    # Skip if log mode is silent
    if config.log_mode == :silent
        return
    end

    # Check if we should log based on iteration or time
    if !should_log_iteration(config, solver_id, iteration) &&
       !should_log_time(config, solver_id)
        return
    end

    # Construct the log message
    msg = "[$solver_id] Iteration $iteration, Error: $error"

    if has_solution
        msg *= ", Solution found"
        if !isnothing(objective_value)
            msg *= ", Objective: $objective_value"
        end
    end

    # Log at info level
    log_info(logger, msg)
end

# Implement the interface function for backward compatibility
function log_solver_state(
        config::LoggerConfig,
        solver_id::String,
        iteration::Int,
        error::Float64,
        has_solution::Bool,
        objective_value::Union{Float64, Nothing} = nothing
)
    log_solver_state(
        Logger(config), solver_id, iteration, error, has_solution, objective_value)
end

"""
    create_logger(;
        level::Union{LogLevel, Symbol} = INFO,
        destinations::Vector{Symbol} = [:console],
        file_path::String = "solver.log",
        log_mode::Symbol = :full,
        update_interval::Float64 = 0.1,
        show_sub_progress::Bool = true,
        show_remote_progress::Bool = true,
        progress_layout::Symbol = :stacked
    )

Create a new Logger with the specified settings.
"""
function create_logger(;
        level::Union{LogLevel, Symbol} = INFO,
        destinations::Vector{Symbol} = [:console],
        file_path::String = "solver.log",
        log_mode::Symbol = :full,
        update_interval::Float64 = 0.1,
        show_sub_progress::Bool = true,
        show_remote_progress::Bool = true,
        progress_layout::Symbol = :stacked
)
    # Convert symbol to LogLevel if needed
    if level isa Symbol
        level = symbol_to_log_level(level)
    end

    return Logger(
        level = level,
        destinations = destinations,
        file_path = file_path,
        log_mode = log_mode,
        update_interval = update_interval,
        show_sub_progress = show_sub_progress,
        show_remote_progress = show_remote_progress,
        progress_layout = progress_layout
    )
end

# Export main functions
export Logger, create_logger
export log_error, log_warn, log_info, log_debug
export reset_logger!, log_solver_state
