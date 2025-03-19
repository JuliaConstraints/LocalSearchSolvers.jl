# Custom logging macros for LocalSearchSolvers

import Logging

"""
    @ls_debug(logger, msg)
    @ls_info(logger, msg)
    @ls_warn(logger, msg)
    @ls_error(logger, msg)

Logging macros that use the LocalSearchSolvers logger system.
These have minimal performance impact when logging is disabled.
"""
macro ls_debug(logger, msg, args...)
    return quote
        logger_instance = $(esc(logger))
        if logger_instance.config.level >= DEBUG
            adapter = LSLoggerAdapter(logger_instance)
            Logging.with_logger(adapter) do
                @debug $(esc(msg)) $(map(esc, args)...)
            end
        end
    end
end

macro ls_info(logger, msg, args...)
    return quote
        logger_instance = $(esc(logger))
        if logger_instance.config.level >= INFO
            adapter = LSLoggerAdapter(logger_instance)
            Logging.with_logger(adapter) do
                @info $(esc(msg)) $(map(esc, args)...)
            end
        end
    end
end

macro ls_warn(logger, msg, args...)
    return quote
        logger_instance = $(esc(logger))
        if logger_instance.config.level >= WARN
            adapter = LSLoggerAdapter(logger_instance)
            Logging.with_logger(adapter) do
                @warn $(esc(msg)) $(map(esc, args)...)
            end
        end
    end
end

macro ls_error(logger, msg, args...)
    return quote
        logger_instance = $(esc(logger))
        if logger_instance.config.level >= LOG_ERROR
            adapter = LSLoggerAdapter(logger_instance)
            Logging.with_logger(adapter) do
                @error $(esc(msg)) $(map(esc, args)...)
            end
        end
    end
end

# Export the macros
export @ls_debug, @ls_info, @ls_warn, @ls_error
