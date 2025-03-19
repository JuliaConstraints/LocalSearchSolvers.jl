# Configuration functions for the logging system
using Dates

"""
    default_log_file_path()

Generate the default path for log files: ~/.julia/constraints/logs/solver_YYYY-MM-DD_HHMMSS.log
"""
function default_log_file_path()
    # Get Julia's user depot path (typically ~/.julia)
    depot_path = DEPOT_PATH[1]

    # Create logs directory if it doesn't exist
    logs_dir = joinpath(depot_path, "constraints", "logs")
    mkpath(logs_dir)

    # Generate timestamped log filename
    timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    return joinpath(logs_dir, "solver_$(timestamp).log")
end

"""
    configure_logger(;
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
function configure_logger(;
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

    # Create a LoggerConfig
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

    # Return a Logger with the config
    return Logger(config)
end

"""
    configure_logger_config(;
        level::Union{LogLevel, Symbol} = INFO,
        destinations::Vector{Symbol} = [:console],
        file_path::String = "solver.log",
        log_mode::Symbol = :full,
        update_interval::Float64 = 0.1,
        show_sub_progress::Bool = true,
        show_remote_progress::Bool = true,
        progress_layout::Symbol = :stacked
    )

Create a new LoggerConfig with the specified settings.
"""
function configure_logger_config(;
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

    return LoggerConfig(
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

"""
    symbol_to_log_level(level::Symbol)

Convert a symbol to a LogLevel enum value.
"""
function symbol_to_log_level(level::Symbol)
    if level == :silent
        return SILENT
    elseif level == :error
        return LOG_ERROR
    elseif level == :warn
        return WARN
    elseif level == :info
        return INFO
    elseif level == :debug
        return DEBUG
    else
        @warn "Unknown log level: $level, defaulting to INFO"
        return INFO
    end
end

"""
    symbol_to_progress_mode(mode::Symbol)

Convert a symbol to a ProgressMode enum value.
"""
function symbol_to_progress_mode(mode::Symbol)
    if mode == :none
        return NONE
    elseif mode == :iteration
        return ITERATION
    elseif mode == :time
        return TIME
    elseif mode == :error
        return ERROR_REDUCTION
    elseif mode == :objective
        return OBJECTIVE
    elseif mode == :mixed
        return MIXED
    elseif mode == :smart
        return SMART
    else
        @warn "Unknown progress mode: $mode, defaulting to SMART"
        return SMART
    end
end

"""
    create_progress_tracker(;
        mode::Union{ProgressMode, Symbol} = MIXED,
        solver_id::String = "Main",
        total_iterations::Union{Int, Nothing} = nothing,
        total_time::Union{Float64, Nothing} = nothing,
        bar_width::Int = 50
    )

Create a new ProgressTracker with the specified settings.
"""
function create_progress_tracker(;
        mode::Union{ProgressMode, Symbol} = MIXED,
        solver_id::String = "Main",
        total_iterations::Union{Int, Nothing} = nothing,
        total_time::Union{Float64, Nothing} = nothing,
        bar_width::Int = 50
)
    # Convert symbol to ProgressMode if needed
    if mode isa Symbol
        mode = symbol_to_progress_mode(mode)
    end

    return ProgressTracker(
        mode = mode,
        solver_id = solver_id,
        total_iterations = total_iterations,
        total_time = total_time,
        bar_width = bar_width
    )
end

"""
    create_progress_tracker_from_options(options::Dict, solver_id::String = "Main")

Create a ProgressTracker based on solver options.
"""
function create_progress_tracker_from_options(options::Dict, solver_id::String = "Main")
    # Extract relevant options
    progress_mode = get(options, "progress_mode", :mixed)
    if progress_mode isa Symbol
        progress_mode = symbol_to_progress_mode(progress_mode)
    end

    # Get iteration limit if available
    total_iterations = nothing
    if haskey(options, "iteration")
        iter_option = options["iteration"]
        if iter_option isa Tuple && length(iter_option) >= 2
            # Handle Inf case
            if iter_option[2] == Inf
                total_iterations = nothing
                # Ensure total_iterations is Int or nothing
            elseif iter_option[2] isa Float64
                total_iterations = Int(iter_option[2])
            else
                total_iterations = iter_option[2]
            end
        elseif iter_option isa Int
            total_iterations = iter_option
        elseif iter_option isa Float64
            # Handle Inf case
            if iter_option == Inf
                total_iterations = nothing
            else
                total_iterations = Int(iter_option)
            end
        end
    end

    # Get time limit if available
    total_time = nothing
    if haskey(options, "time_limit")
        time_option = options["time_limit"]
        if time_option isa Tuple && length(time_option) >= 2
            total_time = time_option[2]
        elseif time_option isa Number
            total_time = time_option
        end
    end

    # Get bar width if available
    bar_width = get(options, "progress_bar_width", 50)

    return ProgressTracker(
        mode = progress_mode,
        solver_id = solver_id,
        total_iterations = total_iterations,
        total_time = total_time,
        bar_width = bar_width
    )
end

"""
    create_progress_tracker_from_options(options::Options, solver_id::String = "Main")

Create a ProgressTracker based on solver options.
"""
function create_progress_tracker_from_options(options::Options, solver_id::String = "Main")
    # Extract relevant options using get_option
    progress_mode = get_option(options, "progress_mode", :mixed)
    if progress_mode isa Symbol
        progress_mode = symbol_to_progress_mode(progress_mode)
    end

    # Get iteration limit
    iter_option = get_option(options, "iteration")
    total_iterations = nothing
    if iter_option isa Tuple && length(iter_option) >= 2
        # Handle Inf case
        if iter_option[2] == Inf
            total_iterations = nothing
            # Ensure total_iterations is Int or nothing
        elseif iter_option[2] isa Float64
            total_iterations = Int(iter_option[2])
        else
            total_iterations = iter_option[2]
        end
    end

    # Get time limit
    time_option = get_option(options, "time_limit")
    total_time = nothing
    if time_option isa Tuple && length(time_option) >= 2
        total_time = time_option[2]
    end

    # Get bar width
    bar_width = get_option(options, "progress_bar_width")

    return ProgressTracker(
        mode = progress_mode,
        solver_id = solver_id,
        total_iterations = total_iterations,
        total_time = total_time,
        bar_width = bar_width
    )
end

"""
    create_logger_from_options(options::Dict)

Create a Logger based on solver options.
"""
function create_logger_from_options(options::Dict)
    # Extract relevant options
    log_level = get(options, "log_level", :info)
    if log_level isa Symbol
        log_level = symbol_to_log_level(log_level)
    end

    log_mode = get(options, "log_mode", :full)
    file_path = get(options, "log_file", "solver.log")
    update_interval = get(options, "progress_update_interval", 0.1)
    show_sub_progress = get(options, "show_sub_progress", true)
    show_remote_progress = get(options, "show_remote_progress", true)
    progress_layout = get(options, "progress_layout", :stacked)

    # Determine destinations
    destinations = Symbol[]
    if get(options, "log_to_file", true)
        push!(destinations, :file)
    end
    if log_mode != :silent
        push!(destinations, :console)
    end

    # Create a LoggerConfig
    config = LoggerConfig(
        level = log_level,
        destinations = destinations,
        file_path = file_path,
        log_mode = log_mode,
        update_interval = update_interval,
        show_sub_progress = show_sub_progress,
        show_remote_progress = show_remote_progress,
        progress_layout = progress_layout
    )

    # Return a Logger with the config
    return Logger(config)
end

"""
    create_logger_from_options(options::Options)

Create a Logger based on solver options.
"""
function create_logger_from_options(options::Options)
    # Extract relevant options using get_option
    log_level = get_option(options, "log_level")
    if log_level isa Symbol
        log_level = symbol_to_log_level(log_level)
    end

    log_mode = get_option(options, "log_mode")
    file_path = get_option(options, "log_file")
    update_interval = get_option(options, "progress_update_interval")
    show_sub_progress = get_option(options, "show_sub_progress")
    show_remote_progress = get_option(options, "show_remote_progress")
    progress_layout = get_option(options, "progress_layout")

    # Determine destinations
    destinations = Symbol[]
    if get_option(options, "log_to_file")
        push!(destinations, :file)
    end
    if log_mode != :silent
        push!(destinations, :console)
    end

    # Create a LoggerConfig
    config = LoggerConfig(
        level = log_level,
        destinations = destinations,
        file_path = file_path,
        log_mode = log_mode,
        update_interval = update_interval,
        show_sub_progress = show_sub_progress,
        show_remote_progress = show_remote_progress,
        progress_layout = progress_layout
    )

    # Return a Logger with the config
    return Logger(config)
end

"""
    create_logger_config_from_options(options::Dict)

Create a LoggerConfig based on solver options.
"""
function create_logger_config_from_options(options::Dict)
    # Extract relevant options
    log_level = get(options, "log_level", :info)
    if log_level isa Symbol
        log_level = symbol_to_log_level(log_level)
    end

    log_mode = get(options, "log_mode", :full)
    file_path = get(options, "log_file", "solver.log")
    update_interval = get(options, "progress_update_interval", 0.1)
    show_sub_progress = get(options, "show_sub_progress", true)
    show_remote_progress = get(options, "show_remote_progress", true)
    progress_layout = get(options, "progress_layout", :stacked)

    # Determine destinations
    destinations = Symbol[]
    if get(options, "log_to_file", true)
        push!(destinations, :file)
    end
    if log_mode != :silent
        push!(destinations, :console)
    end

    return LoggerConfig(
        level = log_level,
        destinations = destinations,
        file_path = file_path,
        log_mode = log_mode,
        update_interval = update_interval,
        show_sub_progress = show_sub_progress,
        show_remote_progress = show_remote_progress,
        progress_layout = progress_layout
    )
end

"""
    create_logger_config_from_options(options::Options)

Create a LoggerConfig based on solver options.
"""
function create_logger_config_from_options(options::Options)
    # Extract relevant options using get_option
    log_level = get_option(options, "log_level")
    if log_level isa Symbol
        log_level = symbol_to_log_level(log_level)
    end

    log_mode = get_option(options, "log_mode")
    file_path = get_option(options, "log_file")
    update_interval = get_option(options, "progress_update_interval")
    show_sub_progress = get_option(options, "show_sub_progress")
    show_remote_progress = get_option(options, "show_remote_progress")
    progress_layout = get_option(options, "progress_layout")

    # Determine destinations
    destinations = Symbol[]
    if get_option(options, "log_to_file")
        push!(destinations, :file)
    end
    if log_mode != :silent
        push!(destinations, :console)
    end

    return LoggerConfig(
        level = log_level,
        destinations = destinations,
        file_path = file_path,
        log_mode = log_mode,
        update_interval = update_interval,
        show_sub_progress = show_sub_progress,
        show_remote_progress = show_remote_progress,
        progress_layout = progress_layout
    )
end
