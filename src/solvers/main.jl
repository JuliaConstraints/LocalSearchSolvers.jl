"""
    MainSolver <: AbstractSolver

Main solver. Handle the solving of a model, and optional multithreaded and/or distributed subsolvers.

# Arguments:
- `model::Model`: A formal description of the targeted problem
- `state::_State`: An internal state to store the info necessary to a solving run
- `options::Options`: User options for this solver
- `subs::Vector{_SubSolver}`: Optional subsolvers
"""
mutable struct MainSolver <: MetaSolver
    meta_local_id::Tuple{Int, Int}
    model::_Model
    options::Options
    @atomic pool::Pool
    rc_report::RemoteChannel
    rc_sol::RemoteChannel
    rc_stop::RemoteChannel
    remotes::Dict{Int, Future}
    state::State
    status::Symbol
    strategies::MetaStrategy
    subs::Vector{_SubSolver}
    iterations::Int
    time_stamps::TimeStamps

    # Logger fields
    progress_tracker::Union{AbstractProgressTracker, Nothing}
    logger::AbstractLogger
    pool_lock::ReentrantLock
    remote_runs::Dict{Int,Future}
    remote_results::Dict{Int,Any}
end

make_id(::Int, id, ::Val{:lead}) = (id, 0)

function solver(model = model();
        options = Options(),
        pool = pool(),
        strategies = MetaStrategy(model)
)
    mlid = (1, 0)
    rc_report = RemoteChannel(() -> Channel{Nothing}(length(workers())))
    rc_sol = RemoteChannel(() -> Channel{Pool}(length(workers())))
    rc_stop = RemoteChannel(() -> Channel{Nothing}(1))
    remotes = Dict{Int, Future}()
    subs = Vector{_SubSolver}()
    ts = TimeStamps(model)

    # Create progress tracker based on solver options
    progress_tracker = create_progress_tracker_from_options(options, "Main")

    # Create logger based on solver options
    logger = create_logger_from_options(options)

    return MainSolver(
        mlid, model, options, pool, rc_report, rc_sol, rc_stop,
        remotes, state(), :not_called, strategies, subs, 0, ts,
        progress_tracker, logger, ReentrantLock(), Dict{Int,Future}(), Dict{Int,Any}()
    )
end

# Forwards from TimeStamps
@forward MainSolver.time_stamps add_time!, time_info, get_time

"""
    empty!(s::Solver)

"""
function Base.empty!(s::MainSolver)
    all(isready, values(s.remote_runs)) || error("cannot empty a solver with unfinished remote runs")
    empty!(s.model)
    s.state = state()
    empty!(s.subs)
    empty!(s.remotes)
    empty!(s.remote_runs)
    empty!(s.remote_results)
    _replace_pool!(s, pool())
    s.iterations = 0
    s.status = :not_called
    return s
end

"""
    status(solver)
Return the status of a MainSolver.
"""
status(s::MainSolver) = s.status
iterations(s::MainSolver) = s.iterations
_iterations!(s::MainSolver, value::Int) = s.iterations = value

function _init!(s::MainSolver)
    _init!(s, :global)
    _init!(s, :remote)
    _init!(s, :meta)
    _init!(s, :local)
end

function stop_while_loop(s::MainSolver, stop::Atomic{Bool}, iter, start_time)
    if stop[]
        s.status = :interrupted
        return false
    end
    if is_sat(s) && _solution_limit_reached(s)
        s.status = :solution_limit
        return false
    end
    # Get iteration and time limit settings
    iter_settings = get_option(s, Val(:iteration))
    time_settings = get_option(s, Val(:time_limit))

    # Extract variables matching logic table
    I = iter_settings[1]  # Stop on iteration only with solution
    L = iter >= iter_settings[2]  # Reached iteration limit
    S = has_solution(s)  # Has solution
    T = time_settings[1]  # Stop on time only with solution
    TL = time() - start_time > time_settings[2]  # Reached time limit

    # Special case: both limits require solution
    if I && T
        # Stop if solution found and either limit reached
        if S && (L || TL)
            s.status = L ? :iteration_limit : :time_limit
            @ls_debug s.logger "Stopping: solution found ($(S)) and $(s.status) reached (iter: $iter/$(iter_settings[2]), time: $(time()-start_time)/$(time_settings[2]))"

            return false
        end
    else
        # Handle iteration limit
        should_stop_iteration = if I
            L && S  # Stop only if limit reached AND has solution
        else
            L      # Stop if limit reached regardless of solution
        end

        # Handle time limit
        should_stop_time = if T
            TL && S  # Stop only if limit reached AND has solution
        else
            TL      # Stop if limit reached regardless of solution
        end

        if should_stop_iteration
            s.status = :iteration_limit
            @ls_debug s.logger "Stopping: iteration limit reached ($(iter)/$(iter_settings[2])) $(I ? "with solution ($(S))" : "(absolute)")"

            return false
        end

        if should_stop_time
            s.status = :time_limit
            @ls_debug s.logger "Stopping: time limit reached ($(time()-start_time)/$(time_settings[2])) $(T ? "with solution ($(S))" : "(absolute)")"
            return false
        end
    end

    return true
end

@testitem "Absolute iteration limits execute exactly the requested work" default_imports=false begin
    import LocalSearchSolvers as LS
    import Test: @test

    function options(limit)
        return LS.Options(
            iteration = limit,
            time_limit = Inf,
            print_level = :silent,
            log_mode = :silent,
            log_to_file = false,
            progress_mode = :none,
            process_threads_map = Dict(1 => 1),
        )
    end

    satisfaction = LS.model()
    foreach(_ -> LS.variable!(satisfaction, LS.domain(1:4)), 1:4)
    LS.constraint!(satisfaction, (x; X) -> 1.0, collect(1:4))
    satisfaction_solver = LS.solver(satisfaction; options = options(3))
    LS.solve!(satisfaction_solver)
    @test LS.status(satisfaction_solver) === :iteration_limit
    @test LS.iterations(satisfaction_solver) == 3
    @test !LS.has_solution(satisfaction_solver)

    optimization = LS.model()
    foreach(_ -> LS.variable!(optimization, LS.domain(1:4)), 1:4)
    LS.constraint!(optimization, (x; X) -> 0.0, collect(1:4))
    LS.objective!(optimization, sum)
    optimization_solver = LS.solver(optimization; options = options(3))
    LS.solve!(optimization_solver)
    @test LS.status(optimization_solver) === :iteration_limit
    @test LS.iterations(optimization_solver) == 3
    @test LS.has_solution(optimization_solver)
end

function remote_dispatch!(s::MainSolver)
    # Register main solver for distributed logging
    register_main_solver(s)

    # Start remote solvers
    for (w, ls) in s.remotes
        s.remote_runs[w] = remotecall(_run_remote_solver, w, ls)
    end

    # Log start of remote solvers if in full mode
    if !isnothing(s.progress_tracker) && s.logger.config.log_mode == :full
        log_info(s.logger, "Started $(length(s.remotes)) remote solver(s)")
    end
end

function post_process(s::MainSolver)
    path = get_option(s, "info_path")
    sat = is_sat(s)
    if s.status == :not_called
        s.status = :solution_limit
    end
    if !isempty(path)
        info = Dict(
            :solution => has_solution(s) ? collect(best_values(s)) : nothing,
            :time => time_info(s),
            :type => sat ? "Satisfaction" : "Optimization"
        )
        !sat && has_solution(s) && push!(info, :value => best_value(s))
        write(path, JSON.json(info))
    end
end

function _signal_remote_stop!(s::MainSolver)
    # Several completion tasks can request cancellation at once. Publish the
    # one-slot signal under a lock so a second writer cannot block on put!.
    lock(s.pool_lock) do
        isready(s.rc_stop) || put!(s.rc_stop, nothing)
    end
    nothing
end

function remote_stop!(s::MainSolver)
    @ls_diagnostic s :summary :remote_collect_begin
    if s.status in (:interrupted, :time_limit) || (is_sat(s) && _solution_limit_reached(s))
        _signal_remote_stop!(s)
    end
    failures = Any[]
    try
        @sync for (worker, completion) in s.remote_runs
            @async try
                result = fetch(completion)
                s.remote_results[worker] = result
                @ls_diagnostic s :summary :remote_pool_received worker=worker incoming=_diagnostic_pool(result.pool)
                update_pool!(s, result.pool)
                is_sat(s) && _solution_limit_reached(s) && _signal_remote_stop!(s)
            catch exception
                push!(failures, exception)
                _signal_remote_stop!(s)
            end
        end
    finally
        _signal_remote_stop!(s)
        unregister_main_solver(s)
    end
    @ls_diagnostic s :summary :remote_collect_end
    isempty(failures) || throw(CompositeException(failures))
    nothing
end
