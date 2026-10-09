module ShortFloatScenarios
using LocalSearchSolvers, Constraints, Random
include("owned_scenarios.jl")
const LS = LocalSearchSolvers

function model(count,precision,arity=2)
    T = precision == "Float32" ? Float32 : precision == "Float64" ? Float64 :
        throw(ArgumentError("float precision $precision"))
    1 <= arity <= count || throw(ArgumentError("invalid constraint arity"))
    result = LS.model()
    foreach(_ -> LS.variable!(result,LS.domain(T(0):T(1):T(7))),1:count)
    evaluator = Constraints.bind_error(Constraints.make_error(:sum);op=<=,val=7)
    for id in 1:count
        LS.constraint!(result,evaluator,[mod1(id+position,count) for position in 0:arity-1])
    end
    LS.objective!(result,sum)
    result
end

function refresh_case(parameters)
    count = get(parameters,"variables",128)
    precision = get(parameters,"precision","Float64")
    arity = get(parameters,"arity",2)
    partial = get(parameters,"partial",false)
    repetitions = get(parameters,"repetitions",4096)
    input_total(id,value) = sum(position -> mod1(id+position,count) == 1 ? value : 4,0:arity-1)
    truth(value) = Float64(Base.count(id -> input_total(id,value) > 7,1:count))
    prepare = () -> begin
        solver = LS.solver(model(count,precision,arity);options=OwnedScenarios.options())
        Random.seed!(41)
        LS._init!(solver)
        state = solver.state
        for id in 1:count
            LS._value!(state,id,4)
        end
        LS._compute_costs!(solver.model,state,())
        affected = Tuple(id for id in 1:count if any(position -> mod1(id+position,count)==1,0:arity-1))
        (;model=solver.model,state,count,affected)
    end
    operation = fixture -> begin
        ids = partial ? fixture.affected : ()
        total = 0.0
        for iteration in 1:repetitions
            LS._value!(fixture.state,1,isodd(iteration) ? 7 : 0)
            LS._compute_costs!(fixture.model,fixture.state,ids)
            total += LS.get_error(fixture.state)
        end
        total
    end
    verify = (fixture,result) -> iseven(repetitions) &&
        result == (repetitions÷2)*(truth(0)+truth(7)) && LS.get_error(fixture.state) == truth(0) &&
        all(id -> LS._cons_cost(fixture.state,id) == Float64(input_total(id,0)>7) &&
            LS._invariant(fixture.state,id).total == input_total(id,0),1:count) &&
        LS._state_assignment(fixture.state)[1] == 0 &&
        all(id -> LS._state_assignment(fixture.state)[id] == 4,2:count)
    (;prepare,operation,verify)
end

function episode_case(parameters)
    count = get(parameters,"variables",32)
    precision = get(parameters,"precision","Float64")
    steps = get(parameters,"steps",128)
    seed = get(parameters,"seed",41)
    prepare = () -> begin
        solver = LS.solver(model(count,precision);options=OwnedScenarios.options())
        LS.prepare_unit(solver;seed,builder=LS.execution_builder(mode=:typed))
    end
    operation = unit -> begin
        LS.reset_unit!(unit)
        LS.run_episode!(unit;iterations=steps)
    end
    verify = (unit,result) -> result.iterations == steps && OwnedScenarios.valid_state(unit.solver.state) &&
        all(id -> LS._cons_cost(unit.solver.state,id) ==
            Constraints.invariant_value(LS._invariant(unit.solver.state,id)),1:count)
    cleanup = unit -> LS.release_unit!(unit)
    (;prepare,operation,verify,cleanup)
end
end
short_float_refresh_case(parameters) = ShortFloatScenarios.refresh_case(parameters)
short_float_episode_case(parameters) = ShortFloatScenarios.episode_case(parameters)
