# Logger interface definitions

"""
    LogLevel

Enumeration of log levels for controlling verbosity.
"""
@enum LogLevel begin
    SILENT = 0  # No logging
    LOG_ERROR = 1   # Only errors
    WARN = 2    # Errors and warnings
    INFO = 3    # Informational messages (default)
    DEBUG = 4   # Detailed debug information
end

"""
    ProgressMode

Enumeration of progress tracking modes.
"""
@enum ProgressMode begin
    NONE = 0        # No progress tracking
    ITERATION = 1   # Track progress by iterations
    TIME = 2        # Track progress by time
    ERROR_REDUCTION = 3  # Track progress by error reduction
    OBJECTIVE = 4   # Track progress by objective improvement
    MIXED = 5       # Automatically select best mode
end

"""
    AbstractLogger

Abstract type for logger implementations.
"""
abstract type AbstractLogger end

"""
    AbstractProgressTracker

Abstract type for progress tracker implementations.
"""
abstract type AbstractProgressTracker end

# Interface functions

"""
    log_message(logger::AbstractLogger, level::LogLevel, message::String)

Log a message with the specified level.
"""
function log_message end

"""
    log_error(logger::AbstractLogger, message::String)

Log an error message.
"""
function log_error end

"""
    log_warn(logger::AbstractLogger, message::String)

Log a warning message.
"""
function log_warn end

"""
    log_info(logger::AbstractLogger, message::String)

Log an informational message.
"""
function log_info end

"""
    log_debug(logger::AbstractLogger, message::String)

Log a debug message.
"""
function log_debug end

"""
    update_progress!(tracker::AbstractProgressTracker; kwargs...)

Update the progress tracker with new solver state information.
"""
function update_progress! end

"""
    display_progress!(tracker::AbstractProgressTracker, logger::AbstractLogger; kwargs...)

Update the terminal display with the current progress.
"""
function display_progress! end

"""
    finalize_progress!(tracker::AbstractProgressTracker, logger::AbstractLogger)

Display the final progress state and add a newline.
"""
function finalize_progress! end

"""
    reset_progress!(tracker::AbstractProgressTracker)

Reset the progress tracker to its initial state.
"""
function reset_progress! end

"""
    enable_progress!(tracker::AbstractProgressTracker, enabled::Bool = true)

Enable or disable the progress tracker.
"""
function enable_progress! end

"""
    set_progress_mode!(tracker::AbstractProgressTracker, mode::Union{ProgressMode, Symbol})

Set the progress tracking mode.
"""
function set_progress_mode! end

"""
    calculate_progress(tracker::AbstractProgressTracker)

Calculate the current progress as a value between 0.0 and 1.0.
"""
function calculate_progress end

# Export interface types and functions
export LogLevel, ProgressMode
export AbstractLogger, AbstractProgressTracker
export log_message, log_error, log_warn, log_info, log_debug
export update_progress!, display_progress!, finalize_progress!
export reset_progress!, enable_progress!, set_progress_mode!
export calculate_progress
