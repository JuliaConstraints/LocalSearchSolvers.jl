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
    pool::Pool
    rc_report::RemoteChannel
    rc_sol::RemoteChannel
    rc_stop::RemoteChannel
    remotes::Dict{Int, Future}
    state::State
    status::Symbol
    strategies::MetaStrategy
    subs::Vector{_SubSolver}
    time_stamps::TimeStamps

    # Logger fields
    progress_tracker::Union{AbstractProgressTracker, Nothing}
    logger::AbstractLogger
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
        remotes, state(), :not_called, strategies, subs, ts,
        progress_tracker, logger
    )
end

# Forwards from TimeStamps
@forward MainSolver.time_stamps add_time!, time_info, get_time

"""
    empty!(s::Solver)

"""
function Base.empty!(s::MainSolver)
    empty!(s.model)
    s.state = state()
    empty!(s.subs)
    # TODO: empty remote solvers
end

"""
    status(solver)
Return the status of a MainSolver.
"""
status(s::MainSolver) = s.status

function _init!(s::MainSolver)
    _init!(s, :global)
    _init!(s, :remote)
    _init!(s, :meta)
    _init!(s, :local)
end

function stop_while_loop(s::MainSolver, ::Atomic{Bool}, iter, start_time)
    # Get iteration and time limit settings
    iter_settings = get_option(s, "iteration")
    time_settings = get_option(s, "time_limit")

    # Extract variables matching logic table
    I = iter_settings[1]  # Stop on iteration only with solution
    L = iter > iter_settings[2]  # Reached iteration limit
    S = has_solution(s)  # Has solution
    T = time_settings[1]  # Stop on time only with solution
    TL = time() - start_time > time_settings[2]  # Reached time limit

    # Special case: both limits require solution
    if I && T
        # Stop if solution found and either limit reached
        if S && (L || TL)
            s.status = L ? :iteration_limit : :time_limit
            _verbose(s.options,
                "Stopping: solution found ($(S)) and $(s.status) reached (iter: $iter/$(iter_settings[2]), time: $(time()-start_time)/$(time_settings[2]))")

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
            _verbose(s.options,
                "Stopping: iteration limit reached ($(iter)/$(iter_settings[2])) $(I ? "with solution ($(S))" : "(absolute)")")

            return false
        end

        if should_stop_time
            s.status = :time_limit
            _verbose(s.options,
                "Stopping: time limit reached ($(time()-start_time)/$(time_settings[2])) $(T ? "with solution ($(S))" : "(absolute)")")
            return false
        end
    end

    return true
end

function remote_dispatch!(s::MainSolver)
    for (w, ls) in s.remotes
        remote_do(solve!, w, fetch(ls))
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

function remote_stop!(s::MainSolver)
    isready(s.rc_stop) && take!(s.rc_stop)
    sat = is_sat(s)
    @info "Remote stop: report main pool" best_values(s.pool) has_solution(s) s.rc_report s.rc_sol s.rc_stop length(s.remotes)
    if !sat || !has_solution(s)
        @warn "debugging remote stop" nworkers() length(s.remotes)
        while isready(s.rc_report) || isready(s.rc_sol)
            wait(s.rc_sol)
            t = take!(s.rc_sol)
            @info "Remote stop: report remote pool" best_values(t) length(s.remotes)
            update_pool!(s, t)
            if sat && has_solution(t)
                empty!(s.rc_report)
                break
            end
            @info "mark 1"
            isready(s.rc_report) && take!(s.rc_report)
            @info "mark 2"
        end
    end
    @info "Remote stop: report best pool" best_values(s.pool) length(s.remotes)
end
