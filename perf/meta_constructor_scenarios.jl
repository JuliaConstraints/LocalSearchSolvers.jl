module MetaConstructorScenarios
using LocalSearchSolvers, Constraints, Random
const LS = LocalSearchSolvers

function constructor_case(parameters)
    count = get(parameters, "variables", 128)
    repetitions = get(parameters, "repetitions", 128)
    kind = get(parameters, "kind", "partial")
    ordered = get(parameters, "ordered", false)
    ranges = get(parameters, "ranges", false)
    stride = get(parameters, "stride", 1)
    kind in ("variable", "full", "partial") || throw(ArgumentError("constructor kind $kind"))
    prepare = () -> begin
        ids = ranges ? (stride == 1 ? (1:count) : (1:stride:count*stride)) : collect(1:count)
        group = LS.MetaVariable(:block, ids)
        requested = kind == "partial" && !ordered ? reverse(ids) : copy(ids)
        replacements = [100+id for id in requested]
        (;ids, group, requested, replacements)
    end
    operation = if kind == "variable"
        state -> [LS.MetaVariable(:block, state.ids) for _ in 1:repetitions]
    elseif kind == "full"
        state -> [LS.MetaMove(state.group, state.replacements) for _ in 1:repetitions]
    else
        state -> [LS.MetaMove(state.group, state.requested, state.replacements)
            for _ in 1:repetitions]
    end
    verify = (state, result) -> begin
        expected_ids = ranges ? collect(1:stride:count*stride) : collect(1:count)
        length(result) == repetitions &&
            state.ids == expected_ids && state.group.variables == expected_ids &&
            state.requested == (kind == "partial" && !ordered ? reverse(state.ids) : state.ids) &&
            state.replacements == [100+id for id in state.requested] &&
            all(value -> value.variables == state.ids &&
                value.variables !== state.ids && value.variables !== state.group.variables &&
                (kind == "variable" || value.replacements == [100+id for id in state.ids] &&
                    value.replacements !== state.replacements), result) &&
            length(unique(objectid(value.variables) for value in result)) == repetitions &&
            (kind == "variable" ||
                length(unique(objectid(value.replacements) for value in result)) == repetitions)
    end
    (;prepare, operation, verify)
end

"Construct each move, commit it through the public solver boundary, and refresh all costs."
function construction_commit_case(parameters)
    count = get(parameters, "variables", 32)
    repetitions = get(parameters, "repetitions", 128)
    partial = get(parameters, "partial", false)
    range_ids = get(parameters, "range_ids", false)
    prepare = () -> begin
        model = LS.model()
        foreach(_ -> LS.variable!(model, LS.domain(0:3)), 1:count)
        evaluator = Constraints.bind_error(Constraints.make_error(:sum); op=<=, val=7)
        for id in 1:count
            LS.constraint!(model, evaluator, [id, mod1(id+1,count)])
        end
        LS.objective!(model, sum)
        solver = LS.solver(model; options=LS.Options(dynamic=false, iteration=1,
            print_level=:silent, log_mode=:silent, log_to_file=false, progress_mode=:none,
            process_threads_map=Dict(1=>1)))
        Random.seed!(41)
        LS._init!(solver)
        (;solver, group=LS.MetaVariable(:block, collect(1:count)),
            replacements=(ones(Int,count), zeros(Int,count)))
    end
    operation = state -> begin
        total = 0.0
        for _ in 1:repetitions, replacements in state.replacements
            ids = range_ids ? (1:count) : state.group.variables
            move = partial ? LS.MetaMove(state.group, ids, replacements) :
                LS.MetaMove(state.group, replacements)
            affected = LS._commit!(state.solver, move)
            LS._compute_committed!(state.solver; cons_lst=affected)
            total += LS.get_value(state.solver)
        end
        total
    end
    verify = (state, result) -> result == repetitions*count &&
        all(iszero, LS.get_values(state.solver)) && LS.get_error(state.solver) == 0.0 &&
        LS.get_value(state.solver) == 0.0 && state.group.variables == collect(1:count) &&
        all(==(1), first(state.replacements)) && all(iszero, last(state.replacements)) &&
        all(id -> Constraints.invariant_value(LS._invariant(state.solver, id)) == 0.0,
            1:count)
    (;prepare, operation, verify)
end
end
meta_constructor_case(p) = MetaConstructorScenarios.constructor_case(p)
construction_commit_case(p) = MetaConstructorScenarios.construction_commit_case(p)
