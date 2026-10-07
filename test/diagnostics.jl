module DiagnosticTests
using Test, Random, Logging
import LocalSearchSolvers as LS
import ConstraintDomains: domain
import JSON

function options(log=nothing; threads=1)
    LS.Options(iteration=(false,8),time_limit=(false,60.0),
        process_threads_map=Dict(1=>threads),print_level=:silent,log_mode=:silent,
        log_to_file=false,progress_mode=:none,use_progress_meter=false,diagnostics=log)
end
function example(log=nothing;threads=1)
    m=LS.model();foreach(_->LS.variable!(m,domain(0:2)),1:2)
    LS.constraint!(m,(x;X)->abs(sum(x)-2.0),1:2)
    LS.objective!(m,x->10.0+x[1]+2x[2])
    LS.solver(m;options=options(log;threads))
end
function lazy_probe(s, counter)
    LS.@ls_diagnostic s :trace :lazy payload=(counter[]+=1)
    nothing
end
function snapshot(s)
    (collect(LS.best_values(s)),LS.best_value(s),LS.has_solution(s),LS.iterations(s))
end

@testset "Opt-in structured diagnostics" begin
    @test_throws ArgumentError LS.DiagnosticLog(level=:unknown)
    @test_throws ArgumentError LS.DiagnosticLog(max_events=0)
    s=example();counter=Ref(0)
    lazy_probe(s,counter)
    @test counter[]==0
    @test (@allocated lazy_probe(s,counter))==0
    log=LS.DiagnosticLog(level=:summary)
    @test LS.Logger().diagnostics===nothing
    @test LS.Logger(;diagnostics=log).diagnostics===log
    @test LS.configure_logger().diagnostics===nothing
    LS.set_option!(s,:diagnostics,log)
    @test LS.get_option(s,:diagnostics)===log
    @test s.logger.diagnostics===log
    @test deepcopy(s.options).diagnostics===log
    lazy_probe(s,counter)
    @test counter[]==0
    LS.set_option!(s,"diagnostics",nothing)
    @test s.logger.diagnostics===nothing

    # Pure callbacks and one trajectory: logging may not consume RNG or alter the result.
    # Compile both paths before comparing runs with the same fixed work budget.
    LS.solve!(example());LS.solve!(example(LS.DiagnosticLog(level=:audit)))
    Random.seed!(1);reference=example();LS.solve!(reference)
    for level in (:summary,:debug,:trace,:audit)
        Random.seed!(1);log=LS.DiagnosticLog(;level,max_events=4000)
        s=example(log);LS.solve!(s)
        @test snapshot(s)==snapshot(reference)
        events=LS.diagnostic_events(log)
        names=getindex.(events,"event")
        @test "solve_start" in names && "solve_end" in names
        @test ("step_begin" in names)==(level!=:summary)
        @test ("candidate" in names)==(level in (:trace,:audit))
        @test ("consistency" in names)==(level==:audit)
        @test getindex.(events,"sequence")==collect(1:length(events))
        @test issorted(getindex.(events,"elapsed_ns"))
        @test all(e->e["process_id"]==getpid(),events)
        @test log.dropped==0
        empty!(events)
        @test !isempty(LS.diagnostic_events(log))
    end

    # Independently verify the audit verdict with an intentionally inconsistent stored pool.
    log=LS.DiagnosticLog(level=:audit);s=example(log);LS._init!(s)
    for (i,v) in enumerate([0,2]);LS._value!(s,i,v);end
    LS._compute!(s);LS._replace_pool!(s,LS.pool(s.state.configuration))
    cached_before=deepcopy(s.state.configuration)
    truth=LS._diagnostic_truth(s)
    @test truth.available && truth.violation==0 && truth.objective==14
    @test truth.score_matches==isequal(LS.best_value(s),14.0)
    @test LS.get_value(s.state.configuration)==LS.get_value(cached_before)
    @test collect(LS._values(s))==collect(cached_before.values)
    @test LS._restart!(s)===LS._optimizing(s)

    # The satisfaction branch has different locals and must support its own event payload.
    m=LS.model();LS.variable!(m,domain(0:1));LS.constraint!(m,(x;X)->1.0-x[1],[1])
    log=LS.DiagnosticLog(level=:summary);s=LS.solver(m;options=options(log))
    LS._init!(s);LS._value!(s,1,0);LS._compute!(s);LS._replace_pool!(s,LS.pool(s.state.configuration))
    LS._step!(s)
    found=only(e for e in LS.diagnostic_events(log) if e["event"]=="satisfaction_found")
    @test found["data"]["values"]==[1]

    # Structured events also participate in standard Julia Logging and its filtering.
    log=LS.DiagnosticLog(level=:audit,emit=true);s=example(log)
    @test_logs (:info,r"CBLS pool_replace") LS.@ls_diagnostic s :summary :pool_replace reason=:test
    @test_logs min_level=Logging.Debug (:debug,r"CBLS step_begin") LS.@ls_diagnostic s :debug :step_begin
    @test_logs min_level=Logging.Debug (:debug,r"CBLS candidate") LS.@ls_diagnostic s :trace :candidate
    @test_logs (:error,r"CBLS inconsistent stored result") LS.@ls_diagnostic s :audit :consistency truth=(available=true,score_matches=false,feasibility_matches=true)

    # Shared local buffer: concurrent producers, ordered records, explicit truncation.
    log=LS.DiagnosticLog(level=:trace,max_events=20)
    solvers=[example() for _ in 1:2]
    foreach(LS._init!,solvers)
    foreach(s->LS.set_option!(s,:diagnostics,log),solvers)
    @sync for solver in solvers
        Threads.@spawn for i in 1:25
            LS.@ls_diagnostic solver :summary :concurrent value=i
        end
    end
    events=LS.diagnostic_events(log)
    @test length(events)==20 && log.dropped==30
    @test getindex.(events,"sequence")==collect(1:20)
    @test issorted(getindex.(events,"elapsed_ns"))

    if Threads.nthreads()>=2
        log=LS.DiagnosticLog(level=:debug,max_events=4000)
        s=example(log;threads=2);LS.solve!(s)
        @test length(unique(e["producer"] for e in LS.diagnostic_events(log)))>=2
        @test s.subs[1].logger.diagnostics===log
        LS.set_option!(s,:diagnostics,nothing)
        @test s.subs[1].logger.diagnostics===nothing
    end

    mktempdir() do dir
        s=example();LS.set_option!(s,:info_path,joinpath(dir,"result.json"))
        @test LS.solve!(s)==filesize(joinpath(dir,"result.json"))
        rm(joinpath(dir,"result.json"))
        log=LS.DiagnosticLog(level=:trace,max_events=2);s=example(log)
        LS.@ls_diagnostic s :summary :nonfinite score=Inf
        LS.@ls_diagnostic s :summary :second
        LS.@ls_diagnostic s :summary :third
        @test isempty(readdir(dir))
        path=joinpath(dir,"events.json")
        @test LS.write_diagnostics(log,path)==path
        data=JSON.parsefile(path)
        @test data["events"][1]["data"]["score"]=="Inf"
        @test data["dropped_events"]==1 && !data["complete_trace"]
        @test !isempty(data["origin_utc"])
        @test readdir(dir)==["events.json"]
        @test_throws ArgumentError LS.write_diagnostics(log,path)
        @test LS.write_diagnostics(log,path;overwrite=true)==path
        @test_throws ArgumentError LS.write_diagnostics(log,joinpath(dir,repeat("a",240)))
    end
end
end
