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
    return MainSolver(mlid, model, options, pool, rc_report, rc_sol, rc_stop,
        remotes, state(), :not_called, strategies, subs, ts)
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
    @debug "debug stop" iter (time()-start_time)
    if !isready(s.rc_stop)
        s.status = :solution_limit
        return false
    end

    iter_sat = get_option(s, "iteration")[1] && has_solution(s)
    iter_limit = iter > get_option(s, "iteration")[2]
    if (iter_sat && iter_limit) || iter_limit
        s.status = :iteration_limit
        return false
    end

    time_sat = get_option(s, "time_limit")[1] && has_solution(s)
    time_limit = time() - start_time > get_option(s, "time_limit")[2]
    if (time_sat && time_limit) || time_limit
        s.status = :time_limit
        return false
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
