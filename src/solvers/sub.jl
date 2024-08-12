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
end

function solver(mlid, model, options, pool, ::RemoteChannel,
        ::RemoteChannel, ::RemoteChannel, strats, ::Val{:sub})
    sub_options = deepcopy(options)
    set_option!(sub_options, "print_level", :silent)
    return _SubSolver(mlid, model, sub_options, pool, state(), strats)
end

_init!(s::_SubSolver) = _init!(s, :local)

stop_while_loop(::_SubSolver, stop, ::Int, ::Float64) = !(stop[])
