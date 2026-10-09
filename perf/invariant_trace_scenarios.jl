module IntegerInvariantTraceScenarios
using LocalSearchSolvers, MetaStrategist, Random, SHA
include("owned_scenarios.jl")
const LS = LocalSearchSolvers

# Complete audit records exclude wall clocks. These identities were captured from
# LocalSearchSolvers 184b421 before the integer refresh change, with Julia 1.13.1.
const GOLDEN = (
    (seed=41, variables=32, events=1546, candidates=900,
        trace="0f7e0764a2c5657d5fdb31f9e412f60b175af9fac2b1a27caf734084ed654ab3",
        rng="ef4c9abd4a2c83ae822a42e3df2760fca3c3343eb685dd87aeb769a41e70a6ad",
        final="cc3030721a94906997bd148a8f447704478ce9b9120cbb9c59b0693fd09d2ace"),
    (seed=41, variables=128, events=1540, candidates=896,
        trace="bb8c8d8bbfa7ca760f107f67358e7483caefb2768c932462928f8d350df72985",
        rng="0853ec364ef6b927a402dcd91a78c03794d7623bb9c09a0b753aa29b01fe99e7",
        final="3ee2d60fb8dbe5280bb156e34e774b733176cd1ed35c04b93ce5a3eb4054a05c"),
    (seed=42, variables=32, events=1551, candidates=900,
        trace="14acf5e99e54b702b6368189a337a264dfb584eea96db0d6aca870e9bf8cb966",
        rng="5259519cbd3339da66d96d3adbadb2000805c89b716a7239538fc2352f571cce",
        final="ad5550b465b649b7d0ea83ba111697926899bbb6a12405a11c1d47f1b203de37"),
    (seed=42, variables=128, events=1537, candidates=896,
        trace="4ac102d13374f3db856bb48272b785386f711abec17be4c203f6daffeaeb74c8",
        rng="29021dd947a04d39f1be8249a5735855bd373b46064463ec9235185d8c369d85",
        final="37c2f35329924ad830448ce4946ad3bbdfc17ad424a6502008ee742de91fddfb"),
    (seed=43, variables=32, events=1555, candidates=900,
        trace="b2cd4a996d1b0629c788c0b1175f76c073369884a1be5462ce8dd4d475575f71",
        rng="bc96f5c0b89c6b50dadcaac0341830a44a09e1e451ef01bab6d406f5745361a3",
        final="65cc03ed54c849b2fb3489a75461595841f1a05233ec713e9616a2403a92fc22"),
    (seed=43, variables=128, events=1534, candidates=896,
        trace="a2ac6901addf88976ecfda50ae4dd1ccf398ade2fcae5e73c10bf5911e5ae2ee",
        rng="3b2297bc2e2753bcdfb849f5dc6bc05325567484d0e6df3e27bfb512b1d35619",
        final="d36cffd781d4a7f0649559684b44fa3313e73190f0631d43704e7f7362dc653a"))

portable(x::AbstractDict) = Tuple((string(k),portable(v)) for (k,v) in
    sort!(collect(pairs(x));by=pair -> string(first(pair))))
portable(x::AbstractVector) = Tuple(map(portable,x))
portable(x::NamedTuple) = map(portable,x)
portable(x) = x
digest(value) = bytes2hex(SHA.sha256(MetaStrategist.canonical_value(value)))

function trace_case(parameters)
    seed = get(parameters,"seed",41)
    count = get(parameters,"variables",32)
    golden = only(filter(row -> row.seed == seed && row.variables == count,GOLDEN))
    prepare = () -> begin
        log = LS.DiagnosticLog(level=:audit,max_events=100000,emit=false)
        solver = LS.solver(OwnedScenarios.ring_model(count);options=OwnedScenarios.options())
        LS.set_option!(solver,Val(:iteration),(false,128))
        LS.set_option!(solver,Val(:diagnostics),log)
        (;solver,log)
    end
    operation = fixture -> begin
        Random.seed!(seed)
        LS.solve!(fixture.solver)
        events = LS.diagnostic_events(fixture.log)
        records = [(;event=event["event"],iteration=event["iteration"],
            cached=event["cached"],data=event["data"]) for event in events]
        (;seed,variables=count,events=length(events),
            candidates=Base.count(event -> event["event"] == "candidate",events),
            trace=digest(portable(records)),
            rng=bytes2hex(SHA.sha256(reinterpret(UInt8,rand(UInt64,64)))),
            final=digest((;values=Tuple(LS.get_values(fixture.solver)),
                error=LS.get_error(fixture.solver),value=LS.get_value(fixture.solver))))
    end
    verify = (fixture,result) -> result == golden && fixture.log.dropped == 0 &&
        LS.iterations(fixture.solver) == 128 && OwnedScenarios.valid_state(fixture.solver.state) &&
        all(LS.diagnostic_events(fixture.log)) do event
            event["event"] == "consistency" || return true
            truth = event["data"]["truth"]
            !get(truth,"available",false) || (truth["score_matches"] && truth["feasibility_matches"])
        end
    (;prepare,operation,verify)
end
end
invariant_trace_case(parameters) = IntegerInvariantTraceScenarios.trace_case(parameters)
