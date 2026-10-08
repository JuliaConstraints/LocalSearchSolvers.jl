module OwnedScenarios
using LocalSearchSolvers, Constraints, MetaStrategist, Random
const LS=LocalSearchSolvers

function ring_model(n)
    n>=8 || throw(ArgumentError("at least eight variables are required"))
    model=LS.model()
    foreach(_->LS.variable!(model,LS.domain(0:7)),1:n)
    for i in 1:n
        LS.constraint!(model,Constraints.bind_error(Constraints.make_error(:sum);op=<=,val=7),
            [i,mod1(i+1,n)])
    end
    LS.objective!(model,sum)
    model
end
options()=LS.Options(dynamic=false,iteration=(false,256),time_limit=Inf,
    process_threads_map=Dict(1=>1),print_level=:silent,log_mode=:silent,
    log_to_file=false,progress_mode=:none,use_progress_meter=false)
violation(values)=Float64(count(i->values[i]+values[mod1(i+1,length(values))]>7,eachindex(values)))
function valid_state(state)
    values=collect(LS.get_values(state))
    error=violation(values)
    all(v->v in 0:7,values) && state.configuration.solution==iszero(error) &&
        state.configuration.value==(iszero(error) ? sum(values) : error)
end

function state_case(parameters)
    n=get(parameters,"variables",128)
    prepare=()->LS.specialize(ring_model(n))
    operation=model->begin;Random.seed!(41);LS.state(model);end
    (;prepare,operation,verify=(model,state)->valid_state(state))
end

function owned_unit(n,seed)
    solver=LS.solver(ring_model(n);options=options())
    LS.prepare_unit(solver;seed,builder=LS.execution_builder(mode=:typed))
end
function reset_case(parameters)
    n=get(parameters,"variables",32)
    prepare=()->begin
        unit=owned_unit(n,41)
        reference=(collect(LS.get_values(unit.solver)),LS.unit_receipt(unit).resources.model.evaluator_types)
        LS.run_episode!(unit;iterations=64)
        (;unit,reference)
    end
    operation=state->LS.reset_unit!(state.unit)
    verify=(state,result)->LS.iterations(result.solver)==0 &&
        collect(LS.get_values(result.solver))==state.reference[1] &&
        LS.unit_receipt(result).resources.model.evaluator_types==state.reference[2] &&
        result.solver.state.neighborhood!==result.baseline.graph.state.neighborhood
    cleanup=state->LS.release_unit!(state.unit)
    (;prepare,operation,verify,cleanup)
end

function episode_case(parameters)
    n=get(parameters,"variables",32);steps=get(parameters,"steps",256)
    prepare=()->(owned_unit(n,41),owned_unit(n,42))
    operation=units->map(fetch,map(u->Threads.@spawn(LS.run_episode!(u;iterations=steps)),units))
    verify=(units,results)->all(r->r.iterations==steps,results) &&
        all(u->valid_state(u.solver.state),units) &&
        units[1].solver.state.neighborhood!==units[2].solver.state.neighborhood
    cleanup=units->foreach(LS.release_unit!,units)
    (;prepare,operation,verify,cleanup)
end

function candidate_case(parameters)
    n=get(parameters,"variables",32);repetitions=get(parameters,"repetitions",1024)
    prepare=()->begin
        solver=LS.solver(ring_model(n);options=options());Random.seed!(41);LS._init!(solver)
        for i in 1:n;LS._value!(solver,i,0);end
        LS._compute!(solver);LS._replace_pool!(solver,LS.pool(solver.state.configuration))
        scope=LS.MetaVariable(:block,1:8)
        (;solver,context=LS._search_context(solver),good=LS.MetaMove(scope,ones(Int,8)),
            bad=LS.MetaMove(scope,fill(7,8)),zero=LS.MetaMove(scope,zeros(Int,8)))
    end
    operation=state->begin
        accepted=rejected=0
        for _ in 1:repetitions
            LS._candidate_cost(state.context,state.bad)>0 || error("expected rejection")
            rejected+=1
            LS._candidate_cost(state.context,state.good)==0 || error("expected acceptance")
            affected=LS._commit!(state.context,state.good)
            LS._compute_committed!(state.solver;cons_lst=affected);accepted+=1
            affected=LS._commit!(state.context,state.zero)
            LS._compute_committed!(state.solver;cons_lst=affected)
        end
        (;accepted,rejected)
    end
    verify=(state,result)->result==(;accepted=repetitions,rejected=repetitions) &&
        all(iszero,LS.get_values(state.solver)) && valid_state(state.solver.state)
    (;prepare,operation,verify)
end
end
state_case(p)=OwnedScenarios.state_case(p)
reset_case(p)=OwnedScenarios.reset_case(p)
episode_case(p)=OwnedScenarios.episode_case(p)
candidate_case(p)=OwnedScenarios.candidate_case(p)
