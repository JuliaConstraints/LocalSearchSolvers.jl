module PublicCommitScenarios
using LocalSearchSolvers, Constraints, Random
const LS=LocalSearchSolvers

function public_commit_case(parameters)
    repetitions=get(parameters,"repetitions",1024)
    incremental=get(parameters,"incremental",true)
    prepare=()->begin
        model=LS.model()
        foreach(_->LS.variable!(model,LS.domain(0:7)),1:32)
        evaluator=incremental ? Constraints.bind_error(Constraints.make_error(:sum);op=<=,val=7) :
            ((values;X)->Float64(sum(values)>7))
        LS.constraint!(model,evaluator,1:8)
        LS.objective!(model,sum)
        solver=LS.solver(model;options=LS.Options(dynamic=false,iteration=1,
            print_level=:silent,log_mode=:silent,log_to_file=false,progress_mode=:none,
            process_threads_map=Dict(1=>1)))
        Random.seed!(41);LS._init!(solver)
        scope=LS.MetaVariable(:block,1:8)
        (;solver,moves=(LS.MetaMove(scope,ones(Int,8)),LS.MetaMove(scope,zeros(Int,8))),
            untouched=[LS.get_value(solver,index) for index in 9:32])
    end
    operation=fixture->begin
        for _ in 1:repetitions,move in fixture.moves
            affected=LS._commit!(fixture.solver,move)
            if incremental
                LS._compute_committed!(fixture.solver;cons_lst=affected)
            else
                LS._compute!(fixture.solver;cons_lst=affected)
            end
        end
        nothing
    end
    verify=(fixture,result)->result===nothing &&
        all(index->iszero(LS.get_value(fixture.solver,index)),1:8) &&
        [LS.get_value(fixture.solver,index) for index in 9:32]==fixture.untouched &&
        LS.get_error(fixture.solver)==0.0 &&
        LS.get_value(fixture.solver)==sum(LS.get_values(fixture.solver))
    (;prepare,operation,verify)
end
end
public_commit_case(p)=PublicCommitScenarios.public_commit_case(p)
