module TabuScenarios
using LocalSearchSolvers
const LS=LocalSearchSolvers

function decay_case(parameters)
    repetitions=get(parameters,"repetitions",1024)
    prepare=()->begin
        strategy=LS.tabu(4,2)
        table=LS.tabu_list(strategy)
        for id in 1:16;LS.set!(table,id,repetitions+2);end
        (;strategy,table)
    end
    operation=fixture->begin
        map!(_->repetitions+2,fixture.table,fixture.table)
        for _ in 1:repetitions;LS.decay_tabu!(fixture.strategy);end
        fixture.table
    end
    verify=(fixture,result)->length(result)==16 && all(==(2),result) && result===fixture.table
    (;prepare,operation,verify)
end

function empty_case(parameters)
    repetitions=get(parameters,"repetitions",1024)
    prepare=()->LS.tabu(4,2)
    operation=strategy->begin
        for _ in 1:repetitions
            LS.decay_tabu!(strategy)
            LS.empty_tabu!(strategy)
        end
        LS.tabu_list(strategy)
    end
    verify=(strategy,result)->isempty(result) && result===LS.tabu_list(strategy)
    (;prepare,operation,verify)
end
end
tabu_decay_case(p)=TabuScenarios.decay_case(p)
tabu_empty_case(p)=TabuScenarios.empty_case(p)
