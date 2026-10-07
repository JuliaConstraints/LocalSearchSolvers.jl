"""
Abstract type to encapsulate all solver types that manages other solvers.
"""
abstract type MetaSolver <: AbstractSolver end

meta_id(s) = s.meta_local_id[1]

make_id(meta, id, ::Val{:sub}) = (meta, id)

function _check_subs(s::MetaSolver)
    isempty(s.subs) && return 0
    current = _pool_snapshot(s)
    for (id, ss) in enumerate(s.subs)
        _pool_improves(current, _pool_snapshot(ss), get_option(s, Val(:solutions))) && return id
    end
    return 0
end

function _merge_local_pools!(s::MetaSolver)
    foreach(subsolver -> update_pool!(s, _pool_snapshot(subsolver)), s.subs)
    return nothing
end

function solve_for_loop!(s::MetaSolver, stop, sat, iter, st)
    @threads for id in 1:min(nthreads(), get_option(s, "threads"))
        try
        if id == 1
            add_time!(s, 3) # only used by MainSolver
            remote_dispatch!(s) # only used by MainSolver
            add_time!(s, 4) # only used by MainSolver
            solve_while_loop!(s, stop, sat, iter, st)
            # Satisfaction trajectories may stop as soon as one solver succeeds.
            # Optimization trajectories must all consume their declared iteration
            # budget so threaded performance and quality comparisons keep constant
            # work per trajectory.
            sat && _solution_limit_reached(s) && atomic_or!(stop, true)
        else
            subsolver = s.subs[id - 1]
            solve!(subsolver, stop)
            sat && _solution_limit_reached(subsolver) && atomic_or!(stop, true)
        end
        catch
            atomic_or!(stop, true)
            rethrow()
        end
    end
    # A subsolver may improve its pool after the main trajectory performs its last
    # in-loop poll. Merge again after the thread barrier so late improvements and
    # solutions cannot be lost.
    _merge_local_pools!(s)
end

@testitem "Threaded trajectories finish fixed work and merge late pools" default_imports=false begin
    import LocalSearchSolvers as LS
    import Test: @test

    if Threads.nthreads() == 1
        @test true # The package's dedicated threaded qualification exercises this branch.
    else
        options = LS.Options(
            iteration = (false, 7),
            time_limit = Inf,
            print_level = :silent,
            log_mode = :silent,
            log_to_file = false,
            progress_mode = :none,
            process_threads_map = Dict(1 => 2),
        )

        unsolved = LS.model()
        foreach(_ -> LS.variable!(unsolved, LS.domain(1:3)), 1:3)
        LS.constraint!(unsolved, (values; X) -> 1.0, 1:3)
        unsolved_solver = LS.solver(unsolved; options)
        LS.solve!(unsolved_solver)
        units = Any[unsolved_solver]
        append!(units, unsolved_solver.subs)
        @test LS.iterations.(units) == [7, 7]
        @test !LS.has_solution(unsolved_solver)

        optimization = LS.model()
        LS.variable!(optimization, LS.domain(1:3))
        LS.constraint!(optimization, (values; X) -> 0.0, 1:1)
        LS.objective!(optimization, sum)
        optimization_solver = LS.solver(optimization; options)
        LS._init!(optimization_solver)
        subsolver = only(optimization_solver.subs)

        main_config = deepcopy(LS.best_config(optimization_solver.pool))
        main_config.solution = true
        main_config.value = 10.0
        LS._replace_pool!(optimization_solver, LS.pool(main_config))
        better_config = deepcopy(main_config)
        better_config.value = 3.0
        LS._replace_pool!(subsolver, LS.pool(better_config))
        LS._merge_local_pools!(optimization_solver)
        @test LS.best_value(optimization_solver) == 3.0

        unsolved_config = deepcopy(better_config)
        unsolved_config.solution = false
        unsolved_config.value = 1.0
        LS._replace_pool!(subsolver, LS.pool(unsolved_config))
        LS._merge_local_pools!(optimization_solver)
        @test LS.has_solution(optimization_solver)
        @test LS.best_value(optimization_solver) == 3.0
    end
end
