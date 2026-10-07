# Custom logging macros for LocalSearchSolvers

import Logging

# Keep the enablement check inferred even when a solver stores an abstract logger.
# The message and metadata must remain inside the macro's conditional branch.
@inline function _log_enabled(logger, level::LogLevel)
    return logger.config.log_mode != :silent && logger.config.level >= level
end

function _log_macro!(logger::Logger, level::LogLevel, message, metadata::NamedTuple)
    formatted = string(message)
    if !isempty(metadata)
        suffix = join(("$key = $(repr(value))" for (key, value) in pairs(metadata)), ", ")
        formatted = "$formatted ($suffix)"
    end
    return log_message(logger, level, formatted)
end

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
        if _log_enabled(logger_instance, DEBUG)
            _log_macro!(logger_instance, DEBUG, $(esc(msg)),
                (; $(map(esc, args)...)))
        end
    end
end

macro ls_info(logger, msg, args...)
    return quote
        logger_instance = $(esc(logger))
        if _log_enabled(logger_instance, INFO)
            _log_macro!(logger_instance, INFO, $(esc(msg)),
                (; $(map(esc, args)...)))
        end
    end
end

macro ls_warn(logger, msg, args...)
    return quote
        logger_instance = $(esc(logger))
        if _log_enabled(logger_instance, WARN)
            _log_macro!(logger_instance, WARN, $(esc(msg)),
                (; $(map(esc, args)...)))
        end
    end
end

macro ls_error(logger, msg, args...)
    return quote
        logger_instance = $(esc(logger))
        if _log_enabled(logger_instance, LOG_ERROR)
            _log_macro!(logger_instance, LOG_ERROR, $(esc(msg)),
                (; $(map(esc, args)...)))
        end
    end
end

# Export the macros
export @ls_debug, @ls_info, @ls_warn, @ls_error

@testitem "Silent logging is lazy and allocation free" default_imports = false begin
    import LocalSearchSolvers as LS
    import Test: @test

    logger = LS.Logger(level = LS.DEBUG, log_mode = :silent, destinations = Symbol[])
    evaluations = Ref(0)
    function silent_debug(logger, evaluations, value)
        LS.@ls_debug logger begin
            evaluations[] += 1
            "value=$value"
        end detail = value
        return value
    end

    @test silent_debug(logger, evaluations, 3) == 3
    @test evaluations[] == 0
    @test @allocated(silent_debug(logger, evaluations, 4)) == 0
end
