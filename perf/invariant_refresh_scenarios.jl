module InvariantRefreshScenarios
using LocalSearchSolvers, Constraints, Random
include("owned_scenarios.jl")
const LS = LocalSearchSolvers

function refresh_case(parameters)
    count = get(parameters,"variables",128)
    partial = get(parameters,"partial",false)
    integer = get(parameters,"integer",true)
    repetitions = get(parameters,"repetitions",4096)
    prepare = () -> begin
        model = if integer
            OwnedScenarios.ring_model(count)
        else
            result = LS.model()
            foreach(_ -> LS.variable!(result,LS.domain(0.0:1.0:7.0)),1:count)
            for id in 1:count
                LS.constraint!(result,Constraints.bind_error(Constraints.make_error(:sum);op=<=,val=7),
                    [id,mod1(id+1,count)])
            end
            LS.objective!(result,sum)
            result
        end
        solver = LS.solver(model;options=OwnedScenarios.options())
        Random.seed!(41)
        LS._init!(solver)
        state = solver.state
        for id in 1:count
            LS._value!(state,id,4)
        end
        LS._compute_costs!(solver.model,state,())
        (;model=solver.model,state,count)
    end
    operation = fixture -> begin
        ids = partial ? (1,fixture.count) : ()
        total = 0.0
        for iteration in 1:repetitions
            LS._value!(fixture.state,1,isodd(iteration) ? 7 : 0)
            LS._compute_costs!(fixture.model,fixture.state,ids)
            total += LS.get_error(fixture.state)
        end
        total
    end
    verify = (fixture,result) -> iseven(repetitions) && result == repetitions*(count-1) &&
        LS.get_error(fixture.state) == count-2 &&
        all(id -> LS._cons_cost(fixture.state,id) == (id in (1,count) ? 0.0 : 1.0),1:count) &&
        LS._state_assignment(fixture.state)[1] == 0 &&
        all(id -> LS._state_assignment(fixture.state)[id] == 4,2:count)
    (;prepare,operation,verify)
end

function episode_case(parameters)
    count = get(parameters,"variables",32)
    steps = get(parameters,"steps",128)
    seed = get(parameters,"seed",41)
    prepare = () -> OwnedScenarios.owned_unit(count,seed)
    operation = unit -> begin
        LS.reset_unit!(unit)
        LS.run_episode!(unit;iterations=steps)
    end
    verify = (unit,result) -> result.iterations == steps &&
        OwnedScenarios.valid_state(unit.solver.state) &&
        all(id -> LS._cons_cost(unit.solver.state,id) ==
            Constraints.invariant_value(LS._invariant(unit.solver.state,id)),1:count)
    cleanup = unit -> LS.release_unit!(unit)
    (;prepare,operation,verify,cleanup)
end
end
invariant_refresh_case(p) = InvariantRefreshScenarios.refresh_case(p)
invariant_episode_case(p) = InvariantRefreshScenarios.episode_case(p)
