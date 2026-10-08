module PoolScenarios
using LocalSearchSolvers
const LS = LocalSearchSolvers

function snapshot_case(parameters)
    count = get(parameters, "variables", 32)
    repetitions = get(parameters, "repetitions", 128)
    prepare = () -> LS.Configuration(false, 1.0, LS.Dictionary(1:count, 1:count))
    operation = config -> begin
        result = LS.pool(config)
        for _ in 2:repetitions
            result = LS.pool(config)
        end
        result
    end
    verify = (config, result) -> begin
        saved = LS.best_config(result)
        saved !== config && saved.values !== config.values &&
            keys(saved.values) !== keys(config.values) &&
            collect(pairs(saved.values)) == collect(pairs(config.values)) &&
            saved.solution == config.solution && saved.value == config.value
    end
    (; prepare, operation, verify)
end

function publication_case(parameters)
    count = get(parameters, "variables", 32)
    repetitions = get(parameters, "repetitions", 128)
    prepare = () -> begin
        solver = LS.solver(; options=LS.Options(solutions=1, print_level=:silent,
            log_mode=:silent, log_to_file=false, progress_mode=:none,
            process_threads_map=Dict(1=>1)))
        config = LS.Configuration(false, Float64(repetitions), LS.Dictionary(1:count, 1:count))
        (; solver, config)
    end
    operation = fixture -> begin
        LS._replace_pool!(fixture.solver, LS.pool())
        accepted = 0
        for step in 1:repetitions
            fixture.config.value = repetitions-step
            accepted += LS._consider_configuration!(fixture.solver, fixture.config)
        end
        accepted
    end
    verify = (fixture, result) -> begin
        saved = LS.best_config(LS._pool_snapshot(fixture.solver))
        result == repetitions && saved.value == 0.0 && !saved.solution &&
            saved !== fixture.config && saved.values !== fixture.config.values &&
            keys(saved.values) !== keys(fixture.config.values) &&
            collect(pairs(saved.values)) == collect(pairs(fixture.config.values))
    end
    (; prepare, operation, verify)
end
end
pool_snapshot_case(p) = PoolScenarios.snapshot_case(p)
pool_publication_case(p) = PoolScenarios.publication_case(p)
