module ShortFloatTraceScenarios
using LocalSearchSolvers, Random, SHA
include("short_float_scenarios.jl")
include("invariant_trace_scenarios.jl")
const LS = LocalSearchSolvers
const Proof = IntegerInvariantTraceScenarios
# Captured from d1c3b81 with Julia 1.13.1. Use a fresh fixture for every solve.
const GOLDEN = (
    (precision="Float32",seed=41,variables=32,events=1546,candidates=900,trace="4be5bf41213f0a85d9440b1402f9ce3b36b383b7fdfb1d24290da1d78e747ebb",rng="ef4c9abd4a2c83ae822a42e3df2760fca3c3343eb685dd87aeb769a41e70a6ad",final="c803b89891965c789b6c2aaaa1d88d0b11af0b0aaf243d94e61e72c63dc55157"),
    (precision="Float32",seed=41,variables=128,events=1540,candidates=896,trace="541ac48396ce317fe756737749ea4d601c910c61019fd7d8edf4b828c7a9e0c8",rng="0853ec364ef6b927a402dcd91a78c03794d7623bb9c09a0b753aa29b01fe99e7",final="101c1cca738c546dd75cf36e45e20f27089e1821dcfc88ed8bbf352cf698a43a"),
    (precision="Float32",seed=42,variables=32,events=1551,candidates=900,trace="625a70147adf183eaab817315613626fc617085069be46478bf5834aa62481eb",rng="5259519cbd3339da66d96d3adbadb2000805c89b716a7239538fc2352f571cce",final="30cc02e3316affadb107922bee86e7fa2df21309888dc9630336c1bfba9d9bc8"),
    (precision="Float32",seed=42,variables=128,events=1537,candidates=896,trace="0662cef22efa2be89bdb49c106f961e2812308590367f6cb221a25f8f495bb46",rng="29021dd947a04d39f1be8249a5735855bd373b46064463ec9235185d8c369d85",final="486a609f97fc303386a41cfbdb25684270425623f3f098ab44cab3aec071ed30"),
    (precision="Float32",seed=43,variables=32,events=1555,candidates=900,trace="b622e9d33d110cfad7136ef10a881eebfe3be07e1e8c8baaf7752718cacd7c6b",rng="bc96f5c0b89c6b50dadcaac0341830a44a09e1e451ef01bab6d406f5745361a3",final="ecd745311c77626aca1bcc376205861b756ce41e208e8cc7f2aa68f340d4e525"),
    (precision="Float32",seed=43,variables=128,events=1534,candidates=896,trace="39e6c8476d41cab14d7f52363776ae8e66f0cb523febf341a3b716bc03a6c0c3",rng="3b2297bc2e2753bcdfb849f5dc6bc05325567484d0e6df3e27bfb512b1d35619",final="7178726a9109bc089b3bee70af9241d6eef2b76b58dfbcd1efa550e71db9bb55"),
    (precision="Float64",seed=41,variables=32,events=1546,candidates=900,trace="9a4fdca194968a2541bfbf7b1a162703f3868444fd0dc8021d88a3ed3cd65c35",rng="ef4c9abd4a2c83ae822a42e3df2760fca3c3343eb685dd87aeb769a41e70a6ad",final="010e094c87df55c36d7de011275d2268a2fcca4719e24fcc85cdeb37217d9df8"),
    (precision="Float64",seed=41,variables=128,events=1540,candidates=896,trace="9a10a3dcfe97841de2a4a88fe170c3b81e2bb623fdb85b359510ea5dbe7cf2c4",rng="0853ec364ef6b927a402dcd91a78c03794d7623bb9c09a0b753aa29b01fe99e7",final="78bac5e3a8c4407f4a30e2d3ee3968b5117420efc98aaa46156c3403314ab664"),
    (precision="Float64",seed=42,variables=32,events=1551,candidates=900,trace="9f4304d363461514ecfa3fbfeccc1a62f15fbeca81df9e02e17c52b8440391d2",rng="5259519cbd3339da66d96d3adbadb2000805c89b716a7239538fc2352f571cce",final="7de5ddde38916f7014bca94e3da6b2921deb9e5e236e4c56fb267d028ebd128f"),
    (precision="Float64",seed=42,variables=128,events=1537,candidates=896,trace="81e50c014e25caf32853f254016c3370e0e8035ddbd286d2c7421dbd723ff033",rng="29021dd947a04d39f1be8249a5735855bd373b46064463ec9235185d8c369d85",final="abff5f02bd700e5ce36c5658ddf72e447c4943f93f5d9304abb8346e60dc4f4c"),
    (precision="Float64",seed=43,variables=32,events=1555,candidates=900,trace="8eeb9634ba82db67beddcda570ea3198eabe9b6031a0a4c4e0f25081163ea7f4",rng="bc96f5c0b89c6b50dadcaac0341830a44a09e1e451ef01bab6d406f5745361a3",final="869604a8383b3d635dc4f3a03e46f3f6c97674672c250934ff2ae3ceeb78be71"),
    (precision="Float64",seed=43,variables=128,events=1534,candidates=896,trace="7841f819dbc589e10f2dfb8696e80c2b1265e4484a21079b618b02eba46a0a49",rng="3b2297bc2e2753bcdfb849f5dc6bc05325567484d0e6df3e27bfb512b1d35619",final="de0e8160142439e6f30324e8fc3caf68987e79493e0cf9097e660989d8f4b9a7"))

function trace_case(parameters)
    precision = get(parameters,"precision","Float64")
    seed = get(parameters,"seed",41)
    count = get(parameters,"variables",32)
    golden = only(filter(row -> row.precision == precision && row.seed == seed &&
        row.variables == count,GOLDEN))
    prepare = () -> begin
        log = LS.DiagnosticLog(level=:audit,max_events=100000,emit=false)
        solver = LS.solver(ShortFloatScenarios.model(count,precision);
            options=ShortFloatScenarios.OwnedScenarios.options())
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
        (;precision,seed,variables=count,events=length(events),
            candidates=Base.count(event -> event["event"]=="candidate",events),
            trace=Proof.digest(Proof.portable(records)),
            rng=bytes2hex(SHA.sha256(reinterpret(UInt8,rand(UInt64,64)))),
            final=Proof.digest((;values=Tuple(LS.get_values(fixture.solver)),
                error=LS.get_error(fixture.solver),value=LS.get_value(fixture.solver))))
    end
    verify = (fixture,result) -> result == golden && fixture.log.dropped == 0 &&
        LS.iterations(fixture.solver) == 128 &&
        ShortFloatScenarios.OwnedScenarios.valid_state(fixture.solver.state) &&
        all(LS.diagnostic_events(fixture.log)) do event
            event["event"] == "consistency" || return true
            truth = event["data"]["truth"]
            !get(truth,"available",false) || (truth["score_matches"] && truth["feasibility_matches"])
        end
    (;prepare,operation,verify)
end
end
short_float_trace_case(parameters) = ShortFloatTraceScenarios.trace_case(parameters)

