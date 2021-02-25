const print_levels = Dict(
    :silent => 0,
    :minimal => 1,
    :partial => 2,
    :verbose => 3,
)

    # # Tabu times
    # get!(s, :tabu_time, length_vars(s) ÷ 2) # 10?
    # get!(s, :local_tabu, setting(s, :tabu_time) ÷ 2)
    # get!(s, :δ_tabu, setting(s, :tabu_time) - setting(s, :local_tabu))# 20-30

"""
    Options

DOCSTRING

# Arguments:
- `dynamic::Bool`: DESCRIPTION
- `iteration::Union{Int, Float64}`: DESCRIPTION
- `print_level::Symbol`: DESCRIPTION
- `solutions::Int`: DESCRIPTION
- `specialize::Bool`: DESCRIPTION
- `tabu_time::Int`: DESCRIPTION
- `tabu_local::Int`: DESCRIPTION
- `tabu_delta::Float64`: DESCRIPTION
- `threads::Int`: DESCRIPTION
- `time_limit::Float64`: DESCRIPTION
- `function Options(; dynamic = false, iteration = 1000, print_level = :minimal, solutions = 1, specialize = !dynamic, tabu_time = 0, tabu_local = 0, tabu_delta = 0.0, threads = typemax(0), time_limit = Time(0))
    #= none:13 =#
    #= none:25 =#
    ds_str = "The model types are specialized to the starting domains, constraints," * " and objectives types. Dynamic elements that add a new type will raise an error!"
    #= none:27 =#
    notds_str = "The solver types are not specialized in a static model context," * " which is sub-optimal."
    #= none:29 =#
    dynamic && (specialize && #= none:29 =# @warn(ds_str))
    #= none:30 =#
    !dynamic && (!specialize && #= none:30 =# @info(notds_str))
    #= none:32 =#
    new(dynamic, iteration, print_level, solutions, specialize, tabu_time, tabu_local, tabu_delta, threads, time_limit)
end`: DESCRIPTION
"""
mutable struct Options
    dynamic::Bool
    iteration::Union{Int,Float64}
    print_level::Symbol
    solutions::Int
    specialize::Bool
    tabu_time::Int
    tabu_local::Int
    tabu_delta::Float64
    threads::Int
    time_limit::Float64 # seconds

    function Options(;
        dynamic=false,
        iteration=10000,
        print_level=:minimal,
        solutions=1,
        specialize=!dynamic,
        tabu_time=0,
        tabu_local=0,
        tabu_delta=0.0,
        threads=typemax(0),
        time_limit= Inf,
    )
        ds_str = "The model types are specialized to the starting domains, constraints," *
        " and objectives types. Dynamic elements that add a new type will raise an error!"
        dynamic && specialize && @warn ds_str

        notds_str = "The solver types are not specialized in a static model context," *
        " which is sub-optimal."        
        !dynamic && !specialize && @info notds_str

<<<<<<< HEAD
        itertime_str = "Both iteration and time limits are disabled. " * 
        "Optimization runs will run infinitely."
        iteration == Inf && time_limit == Inf && @warn itertime_str
=======
        itertime_str = "Both iteration and time limits are disabled. Optimization runs will run infinitely."
        iteration == Inf == time_limit && @warn itertime_str
>>>>>>> main

        new(
            dynamic,
            iteration,
            print_level,
            solutions,
            specialize,
            tabu_time,
            tabu_local,
            tabu_delta,
            threads,
            time_limit,
        )
    end
end

"""
    _verbose(settings, str)
Temporary logging function. #TODO: use better log instead (LoggingExtra.jl)
"""
function _verbose(options, str)
    pl = options.print_level
    print_levels[pl] ≥ 3 && (@info str)
end

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
    _iteration(options) = begin

DOCSTRING
"""
_iteration(options) = options.iteration

"""
    _iteration!(options, iterations) = begin

DOCSTRING
"""
_iteration!(options, iterations) = options.iteration = iterations

"""
    _print_level(options) = begin

DOCSTRING
"""
_print_level(options) = options.print_level

"""
    _print_level!(options, level) = begin

DOCSTRING
"""
_print_level!(options, level) = options.print_level = print_levels[level]

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
_threads(options) = options.threads

"""
    _threads!(options, threads) = begin

DOCSTRING
"""
_threads!(options, threads) = options.threads = threads

"""
    _time_limit(options) = begin

DOCSTRING
"""
_time_limit(options) = options.time_limit

"""
    _time_limit!(options, time::Time) = begin

DOCSTRING
"""
_time_limit!(options, time) = options.time_limit = time
