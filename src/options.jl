const print_levels = Dict(
    :silent => 0,
    :minimal => 1,
    :partial => 2,
    :verbose => 3
)

const log_modes = Dict(
    :silent => 0,  # No output
    :minimal => 1, # Only progress bars
    :full => 2     # Full logging with progress bars
)

"""
    Options()
# Arguments:
- `dynamic::Bool`: is the model dynamic?
- `iteration::Union{Int, Float64}`: limit on the number of iterations
- `print_level::Symbol`: verbosity to choose among `:silent`, `:minimal`, `:partial`, `:verbose`
- `solutions::Int`: number of solutions to return
- `specialize::Bool`: should the types of the model be specialized or not. Usually yes for static problems. For dynamic in depends if the user intend to introduce new types. The specialized model is about 10% faster.
- `tabu_time::Int`: DESCRIPTION
- `tabu_local::Int`: DESCRIPTION
- `tabu_delta::Float64`: DESCRIPTION
- `threads::Int`: Number of threads to use
- `time_limit::Float64`: time limit in seconds
- `function Options(; dynamic = false, iteration = 10000, print_level = :minimal, solutions = 1, specialize = !dynamic, tabu_time = 0, tabu_local = 0, tabu_delta = 0.0, threads = typemax(0), time_limit = Inf)

```julia
# Setting options in JuMP syntax: print_level, time_limit, iteration
model = Model(CBLS.Optimizer)
set_optimizer_attribute(model, "iteration", 100)
set_optimizer_attribute(model, "print_level", :verbose)
set_time_limit_sec(model, 5.0)
```
"""
mutable struct Options
    dynamic::Bool
    info_path::String
    iteration::Tuple{Bool, Union{Int, Float64}}
    print_level::Symbol
    process_threads_map::Dict{Int, Int}
    solutions::Int
    specialize::Bool
    tabu_time::Int
    tabu_local::Int
    tabu_delta::Float64
    time_limit::Tuple{Bool, Float64} # seconds

    # Logger options
    log_level::Symbol
    log_mode::Symbol
    log_to_file::Bool
    log_file::String
    progress_mode::Symbol
    progress_bar_width::Int
    progress_update_interval::Float64
    show_sub_progress::Bool
    show_remote_progress::Bool
    progress_layout::Symbol
    use_progress_meter::Bool

    function Options(;
            dynamic = false,
            info_path = "",
            iteration = (false, 100),
            print_level = :minimal,
            process_threads_map = Dict{Int, Int}(1 => typemax(0)),
            solutions = 1,
            specialize = !dynamic,
            tabu_time = 0,
            tabu_local = 0,
            tabu_delta = 0.0,
            time_limit = (false, 1.0), # seconds

            # Logger options
            log_level = :info,
            log_mode = :minimal,
            log_to_file = true,
            log_file = "solver.log", # Default will be set after construction
            progress_mode = :smart,
            progress_bar_width = 50,
            progress_update_interval = 0.1,
            show_sub_progress = false,
            show_remote_progress = false,
            progress_layout = :stacked,
            use_progress_meter = true
    )
        # Use standard warnings instead of custom logger to avoid circular dependencies
        if dynamic && specialize
            @warn "The model types are specialized to the starting domains, constraints, and objectives types. Dynamic elements that add a new type will raise an error!"
        end

        if !dynamic && !specialize
            @info "The solver types are not specialized in a static model context, which is sub-optimal."
        end

        new_iteration = if iteration isa Tuple{Bool, Union{Int, Float64}}
            iteration
        else
            iteration = (false, iteration)
        end

        new_time_limit = if time_limit isa Tuple{Bool, Float64}
            time_limit
        else
            time_limit = (false, time_limit)
        end

        if new_iteration[2] == Inf && new_time_limit[2] == Inf
            @warn "Both iteration and time limits are disabled. Optimization runs will run infinitely."
        end

        new(
            dynamic,
            info_path,
            new_iteration,
            print_level,
            process_threads_map,
            solutions,
            specialize,
            tabu_time,
            tabu_local,
            tabu_delta,
            new_time_limit,

            # Logger options
            log_level,
            log_mode,
            log_to_file,
            log_file,
            progress_mode,
            progress_bar_width,
            progress_update_interval,
            show_sub_progress,
            show_remote_progress,
            progress_layout,
            use_progress_meter
        )
    end
end

# _verbose function removed as it's no longer needed

"""
    _dynamic(options) = begin

DOCSTRING
"""
_dynamic(options) = options.dynamic

"""
    _dynamic!(options, dynamic) = begin

DOCSTRING
"""
_dynamic!(options, dynamic) = options.dynamic = dynamic

"""
    _info_path(options, path)

DOCSTRING
"""
_info_path(options) = options.info_path

"""
    _info_path!(options, iterations) = begin

DOCSTRING
"""
_info_path!(options, path) = options.info_path = path

"""
    _iteration(options) = begin

DOCSTRING
"""
_iteration(options) = options.iteration

"""
    _iteration!(options, iterations) = begin

DOCSTRING
"""
_iteration!(options, iterations) = options.iteration = iterations
function _iteration!(options, iterations::Union{Int, Float64})
    options.iteration = (false, iterations)
end

"""
    _print_level(options) = begin

DOCSTRING
"""
_print_level(options) = options.print_level

"""
    _print_level!(options, level) = begin

DOCSTRING
"""
_print_level!(options, level) = options.print_level = level

"""
    _process_threads_map(options)

TBW
"""
_process_threads_map(options) = options.process_threads_map

"""
    _process_threads_map!(options, ptm)

TBW
"""
_process_threads_map!(options, ptm::AbstractDict) = options.process_threads_map = ptm

function _process_threads_map!(options, ptm::AbstractVector)
    return _process_threads_map!(options, Dict(enumerate(ptm)))
end

"""
    _solutions(options) = begin

DOCSTRING
"""
_solutions(options) = options.solutions

"""
    _solutions!(options, solutions) = begin

DOCSTRING
"""
_solutions!(options, solutions) = options.solutions = solutions

"""
    _specialize(options) = begin

DOCSTRING
"""
_specialize(options) = options.specialize

"""
    _specialize!(options, specialize) = begin

DOCSTRING
"""
_specialize!(options, specialize) = options.specialize = specialize

"""
    _tabu_time(options) = begin

DOCSTRING
"""
_tabu_time(options) = options.tabu_time

"""
    _tabu_time!(options, time) = begin

DOCSTRING
"""
_tabu_time!(options, time) = options.tabu_time = time

"""
    _tabu_local(options) = begin

DOCSTRING
"""
_tabu_local(options) = options.tabu_local

"""
    _tabu_local!(options, time) = begin

DOCSTRING
"""
_tabu_local!(options, time) = options.tabu_local = time

"""
    _tabu_delta(options) = begin

DOCSTRING
"""
_tabu_delta(options) = options.tabu_delta

"""
    _tabu_delta!(options, time) = begin

DOCSTRING
"""
_tabu_delta!(options, time) = options.tabu_delta = time

"""
    _threads(options) = begin

DOCSTRING
"""
_threads(options, p = 1) = get!(options.process_threads_map, p, typemax(0))

"""
    _threads!(options, threads) = begin

DOCSTRING
"""
_threads!(options, threads, p = 1) = push!(options.process_threads_map, p => threads)

"""
    _time_limit(options)

DOCSTRING
"""
_time_limit(options) = options.time_limit

"""
    _time_limit!(options, time::Time) = begin

DOCSTRING
"""
_time_limit!(options, time::Tuple{Bool, Float64}) = options.time_limit = time
_time_limit!(options, time::Float64) = options.time_limit = (false, time)

# Logger option accessors

"""
    _log_level(options, default = nothing)

Get the log level from options. If a default value is provided and the option is not set, return the default.
"""
_log_level(options, default = nothing) = default === nothing ? options.log_level : default

"""
    _log_level!(options, level)

Set the log level in options.
"""
_log_level!(options, level) = options.log_level = level

"""
    _log_mode(options, default = nothing)

Get the log mode from options. If a default value is provided and the option is not set, return the default.
"""
_log_mode(options, default = nothing) = default === nothing ? options.log_mode : default

"""
    _log_mode!(options, mode)

Set the log mode in options.
"""
_log_mode!(options, mode) = options.log_mode = mode

"""
    _log_to_file(options, default = nothing)

Get the log to file flag from options. If a default value is provided and the option is not set, return the default.
"""
_log_to_file(options, default = nothing) = default === nothing ? options.log_to_file :
                                           default

"""
    _log_to_file!(options, flag)

Set the log to file flag in options.
"""
_log_to_file!(options, flag) = options.log_to_file = flag

"""
    _log_file(options, default = nothing)

Get the log file path from options. If a default value is provided and the option is not set, return the default.
"""
_log_file(options, default = nothing) = default === nothing ? options.log_file : default

"""
    _log_file!(options, path)

Set the log file path in options.
"""
_log_file!(options, path) = options.log_file = path

"""
    _progress_mode(options, default = nothing)

Get the progress mode from options. If a default value is provided and the option is not set, return the default.
"""
_progress_mode(options, default = nothing) = default === nothing ? options.progress_mode :
                                             default

"""
    _progress_mode!(options, mode)

Set the progress mode in options.
"""
_progress_mode!(options, mode) = options.progress_mode = mode

"""
    _progress_bar_width(options, default = nothing)

Get the progress bar width from options. If a default value is provided and the option is not set, return the default.
"""
_progress_bar_width(options, default = nothing) = default === nothing ?
                                                  options.progress_bar_width : default

"""
    _progress_bar_width!(options, width)

Set the progress bar width in options.
"""
_progress_bar_width!(options, width) = options.progress_bar_width = width

"""
    _progress_update_interval(options, default = nothing)

Get the progress update interval from options. If a default value is provided and the option is not set, return the default.
"""
_progress_update_interval(options, default = nothing) = default === nothing ?
                                                        options.progress_update_interval :
                                                        default

"""
    _progress_update_interval!(options, interval)

Set the progress update interval in options.
"""
_progress_update_interval!(options, interval) = options.progress_update_interval = interval

"""
    _show_sub_progress(options, default = nothing)

Get the show sub-solver progress flag from options. If a default value is provided and the option is not set, return the default.
"""
_show_sub_progress(options, default = nothing) = default === nothing ?
                                                 options.show_sub_progress : default

"""
    _show_sub_progress!(options, flag)

Set the show sub-solver progress flag in options.
"""
_show_sub_progress!(options, flag) = options.show_sub_progress = flag

"""
    _show_remote_progress(options, default = nothing)

Get the show remote solver progress flag from options. If a default value is provided and the option is not set, return the default.
"""
_show_remote_progress(options, default = nothing) = default === nothing ?
                                                    options.show_remote_progress : default

"""
    _show_remote_progress!(options, flag)

Set the show remote solver progress flag in options.
"""
_show_remote_progress!(options, flag) = options.show_remote_progress = flag

"""
    _progress_layout(options, default = nothing)

Get the progress layout from options. If a default value is provided and the option is not set, return the default.
"""
_progress_layout(options, default = nothing) = default === nothing ?
                                               options.progress_layout : default

"""
    _progress_layout!(options, layout)

Set the progress layout in options.
"""
_progress_layout!(options, layout) = options.progress_layout = layout

"""
    _use_progress_meter(options, default = nothing)

Get the use progress meter flag from options. If a default value is provided and the option is not set, return the default.
"""
_use_progress_meter(options, default = nothing) = default === nothing ?
                                                  options.use_progress_meter : default

"""
    _use_progress_meter!(options, flag)

Set the use progress meter flag in options.
"""
_use_progress_meter!(options, flag) = options.use_progress_meter = flag

function set_option!(options, name, value)
    eval(Symbol("_" * name * "!"))(options, value)
end

function get_option(options, name, args...)
    eval(Symbol("_" * name))(options, args...)
end
