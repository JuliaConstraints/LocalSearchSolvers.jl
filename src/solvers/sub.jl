"""
    _SubSolver <: AbstractSolver

An internal solver type called by MetaSolver when multithreading is enabled.

# Arguments:
- `id::Int`: subsolver id for debugging
- `model::Model`: a ref to the model of the main solver
- `state::_State`: a `deepcopy` of the main solver that evolves independently
- `options::Options`: a ref to the options of the main solver
"""
mutable struct _SubSolver <: AbstractSolver
    meta_local_id::Tuple{Int, Int}
    model::_Model
    options::Options
    pool::Pool
    state::State
    strategies::MetaStrategy

    # Logger fields
    progress_tracker::Union{AbstractProgressTracker, Nothing}
    logger::AbstractLogger
end

function solver(mlid, model, options, pool, ::RemoteChannel,
        ::RemoteChannel, ::RemoteChannel, strats, ::Val{:sub})
    sub_options = deepcopy(options)
    set_option!(sub_options, "print_level", :silent)

    # Create progress tracker for sub-solver
    sub_id = "Sub$(mlid[2])"
    progress_tracker = create_progress_tracker_from_options(sub_options, sub_id)

    # Create logger for sub-solver
    logger = create_logger_from_options(sub_options)

    return _SubSolver(
        mlid, model, sub_options, pool, state(), strats,
        progress_tracker, logger
    )
end

_init!(s::_SubSolver) = _init!(s, :local)

stop_while_loop(::_SubSolver, stop, ::Int, ::Float64) = !(stop[])
