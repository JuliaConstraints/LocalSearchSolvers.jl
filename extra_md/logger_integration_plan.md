# Logger Integration Plan

## Overview

This document outlines the plan for enhancing the logging system in LocalSearchSolvers by:

1. Replacing classic Julia logging macros (`@info`, `@warn`, etc.) with custom logger macros
2. Removing any `_verbose` calls
3. Replacing `println` and similar functions with appropriate logger calls
4. Cleaning up progress bar code that isn't used for ProgressMeter.jl integration

## Implementation Strategy

### 1. Create Custom Logger Macros

Create macros that leverage Julia's standard logging system but use our custom logger:

```julia
# In src/logger/macros.jl
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
```

### 2. Create Logger Adapter

Create a bridge between Julia's standard logging system and our custom logger:

```julia
# In src/logger/logging_adapter.jl
import Logging

"""
    LSLoggerAdapter <: Logging.AbstractLogger

Adapter that bridges Julia's standard logging system with LocalSearchSolvers' custom logger.
"""
struct LSLoggerAdapter <: Logging.AbstractLogger
    logger::Logger
    min_level::Logging.LogLevel

    # Constructor
    function LSLoggerAdapter(logger::Logger; min_level=nothing)
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

function Logging.handle_message(logger::LSLoggerAdapter, level, message, _module, group, id,
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
```

### 3. Update LocalSearchSolvers.jl

Update the main module file to include the new logger components:

```julia
# In src/LocalSearchSolvers.jl
# Add imports
using Logging

# Include new logger files
include("logger/logging_adapter.jl")
include("logger/macros.jl")

# Export new macros
export @ls_debug, @ls_info, @ls_warn, @ls_error
```

### 4. Clean Up Progress Bar Code

1. Identify and remove any unused progress bar code that isn't related to ProgressMeter.jl integration
2. Ensure that the ProgressMeterTracker implementation is the primary progress tracking mechanism
3. Remove any duplicate or redundant progress tracking code

## File Replacement Plan

### 1. Create Tracking File

Create a file in `extra_md` to track which files have been processed:

```markdown
# Logger Integration Progress

## Files Processed

| File | Status | Notes |
|------|--------|-------|
| (file path) | (Completed/In Progress) | (Any notes about changes) |
```

### 2. Process Files Systematically

Process all files in the `src` directory to replace:

1. Classic Julia logging macros (`@info`, `@warn`, `@error`, `@debug`)
2. Any `_verbose` calls (remove them)
3. Any `println` or similar functions

#### Replacement Rules

| Original | Replacement |
|----------|-------------|
| `@info "message"` | `@ls_info logger "message"` |
| `@warn "message"` | `@ls_warn logger "message"` |
| `@error "message"` | `@ls_error logger "message"` |
| `@debug "message"` | `@ls_debug logger "message"` |
| `_verbose(s, "message")` | (remove) |
| `println("message")` | `log_info(logger, "message")` |

### 3. Special Cases

1. **Logger Access**: In some contexts, the logger might not be directly accessible. In these cases, we'll need to:
   - Add logger parameters to functions
   - Use a global logger in some cases
   - Access the logger through a parent object

2. **Progress Bar Integration**: Ensure that progress bar updates are properly integrated with the logging system:
   - Coordinate terminal output between loggers and progress bars
   - Ensure progress updates don't interfere with log messages

## Testing Strategy

1. **Functionality Testing**: Ensure all logging functionality works as expected
2. **Performance Testing**: Verify that logging has minimal impact when disabled
3. **Integration Testing**: Test the integration with ProgressMeter.jl

## Implementation Sequence

1. Create the logger adapter and macros
2. Update the main module file
3. Clean up progress bar code
4. Process files systematically, updating the tracking file as we go
5. Test the implementation

## Files to Process

Based on the project structure, we'll need to process these files:

1. src/LocalSearchSolvers.jl
2. src/strategy.jl
3. src/options.jl
4. src/logger/*.jl
5. src/solvers/*.jl
6. Other files in src/ that contain logging statements
