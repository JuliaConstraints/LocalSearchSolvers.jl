"""
Abstract type to encapsulate all solver types that manages other solvers.
"""
abstract type MetaSolver <: AbstractSolver end

meta_id(s) = s.meta_local_id[1]

make_id(meta, id, ::Val{:sub}) = (meta, id)

function _check_subs(s::MetaSolver)
    if is_sat(s)
        for (id, ss) in enumerate(s.subs)
            has_solution(ss) && return id
        end
    else
        for (id, ss) in enumerate(s.subs)
            bs = is_empty(s.pool) ? nothing : best_value(s)
            bss = is_empty(ss.pool) ? nothing : best_value(ss)
            isnothing(bs) && (isnothing(bss) ? continue : return id)
            isnothing(bss) ? continue : (bss < bs && return id)
        end
    end
    return 0
end

function solve_for_loop!(s::MetaSolver, stop, sat, iter, st)
    @threads for id in 1:min(nthreads(), get_option(s, "threads"))
        if id == 1
            add_time!(s, 3) # only used by MainSolver
            remote_dispatch!(s) # only used by MainSolver
            add_time!(s, 4) # only used by MainSolver
            solve_while_loop!(s, stop, sat, iter, st)
            atomic_or!(stop, true)
        else
            solve!(s.subs[id - 1], stop)
        end
    end
end
