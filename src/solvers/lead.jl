"""
    LeadSolver <: MetaSolver
Solver managed remotely by a MainSolver. Can manage its own set of local sub solvers.
"""
mutable struct LeadSolver <: MetaSolver
    meta_local_id::Tuple{Int, Int}
    model::_Model
    options::Options
    pool::Pool
    rc_report::RemoteChannel
    rc_sol::RemoteChannel
    rc_stop::RemoteChannel
    state::State
    strategies::MetaStrategy
    subs::Vector{_SubSolver}
end

function solver(
        mlid, model, options, pool, rc_report, rc_sol, rc_stop, strats, ::Val{:lead})
    l_options = deepcopy(options)
    set_option!(l_options, "print_level", :silent)
    ss = Vector{_SubSolver}()
    return LeadSolver(
        mlid, model, l_options, pool, rc_report, rc_sol, rc_stop, state(), strats, ss)
end

function _init!(s::LeadSolver)
    _init!(s, :meta)
    _init!(s, :local)
end

stop_while_loop(s::LeadSolver, ::Atomic{Bool}, ::Int, ::Float64) = isready(s.rc_stop)

function remote_stop!(s::LeadSolver)
    isready(s.rc_stop) && take!(s.rc_stop)
    put!(s.rc_sol, s.pool)
    take!(s.rc_report)
end
