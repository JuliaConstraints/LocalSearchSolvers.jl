# Logger adapter for Julia's standard logging system

import Logging

"""
    LSLoggerAdapter <: Logging.AbstractLogger

Adapter that bridges Julia's standard logging system with LocalSearchSolvers' custom logger.
"""
struct LSLoggerAdapter <: Logging.AbstractLogger
    logger::Logger
    min_level::Logging.LogLevel

    # Constructor
    function LSLoggerAdapter(logger::Logger; min_level = nothing)
        # Convert our LogLevel to Logging.LogLevel if not provided
        if isnothing(min_level)
            min_level = convert_to_logging_level(logger.config.level)
        end
        return new(logger, min_level)
    end
end

# Implement AbstractLogger interface
function Logging.shouldlog(logger::LSLoggerAdapter, level, _module, group, id)
    # Convert Logging.LogLevel to our LogLevel
    ls_level = convert_log_level(level)
    return ls_level <= logger.logger.config.level
end

function Logging.min_enabled_level(logger::LSLoggerAdapter)
    return logger.min_level
end

function Logging.handle_message(
        logger::LSLoggerAdapter, level, message, _module, group, id,
        filepath, line; kwargs...)
    # Convert Logging.LogLevel to our LogLevel
    ls_level = convert_log_level(level)

    # Format message with kwargs if any
    formatted_msg = string(message)
    if !isempty(kwargs)
        kwargs_str = join(["$k = $(repr(v))" for (k, v) in kwargs], ", ")
        formatted_msg = "$formatted_msg ($kwargs_str)"
    end

    # Use our existing logging functions
    if ls_level == LOG_ERROR
        log_error(logger.logger, formatted_msg)
    elseif ls_level == WARN
        log_warn(logger.logger, formatted_msg)
    elseif ls_level == INFO
        log_info(logger.logger, formatted_msg)
    elseif ls_level == DEBUG
        log_debug(logger.logger, formatted_msg)
    end
end

# Helper functions to convert between logging levels
function convert_log_level(level::Logging.LogLevel)
    if level == Logging.Error
        return LOG_ERROR
    elseif level == Logging.Warn
        return WARN
    elseif level == Logging.Info
        return INFO
    else  # Debug or lower
        return DEBUG
    end
end

function convert_to_logging_level(level::LogLevel)
    if level == LOG_ERROR
        return Logging.Error
    elseif level == WARN
        return Logging.Warn
    elseif level == INFO
        return Logging.Info
    else  # DEBUG
        return Logging.Debug
    end
end

# Export the adapter
export LSLoggerAdapter, convert_log_level, convert_to_logging_level
