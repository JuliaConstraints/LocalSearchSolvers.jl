module PreparedWorkspaceRegressionTests
using Test, Random, Constraints, MetaStrategist
import LocalSearchSolvers as LS

function unit(seed)
    model=LS.model()
    foreach(_->LS.variable!(model,LS.domain(0:7)),1:32)
    for i in 1:32
        LS.constraint!(model,Constraints.bind_error(Constraints.make_error(:sum);op=<=,val=7),
            [i,mod1(i+1,32)])
    end
    LS.objective!(model,sum)
    solver=LS.solver(model;options=LS.Options(dynamic=false,iteration=(false,64),time_limit=Inf,
        process_threads_map=Dict(1=>1),print_level=:silent,log_mode=:silent,
        log_to_file=false,progress_mode=:none))
    LS.prepare_unit(solver;seed,builder=LS.execution_builder(mode=:typed))
end
snapshot(u)=(collect(LS.get_values(u.solver)),collect(LS.best_values(u.solver)),
    LS.best_value(u.solver),LS.iterations(u.solver))

@testset "Private typed workers reset and replay exact work" begin
    units=(unit(41),unit(42))
    @test units[1].solver.state.constraint_input!==units[2].solver.state.constraint_input
    @test units[1].solver.state.invariants!==units[2].solver.state.invariants
    @test units[1].solver.state.neighborhood!==units[2].solver.state.neighborhood
    for u in units
        descriptions=LS.unit_receipt(u).resources.model.evaluator_types
        @test descriptions==Tuple(string(typeof(c.f)) for c in LS.get_constraints(u.solver.model))
    end
    run()=map(fetch,map(u->Threads.@spawn(LS.run_episode!(u;iterations=64)),units))
    results=run()
    @test all(r->r.iterations==64,results)
    expected=map(snapshot,units)
    foreach(LS.reset_unit!,units)
    @test units[1].solver.state.constraint_input!==units[2].solver.state.constraint_input
    @test all(u->LS.iterations(u.solver)==0,units)
    @test all(r->r.iterations==64,run())
    @test map(snapshot,units)==expected
    for u in units
        values=collect(LS.get_values(u.solver))
        violation=count(i->values[i]+values[mod1(i+1,32)]>7,1:32)
        @test LS.get_error(u.solver)==violation
        if LS.has_solution(u.solver)
            best=collect(LS.best_values(u.solver))
            @test all(i->best[i]+best[mod1(i+1,32)]<=7,1:32)
            @test LS.best_value(u.solver)==sum(best)
        end
        LS.release_unit!(u)
    end
end
end
