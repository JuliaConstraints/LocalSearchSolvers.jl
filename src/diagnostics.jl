"""Bounded opt-in solver events. Levels: :summary, :debug, :trace, :audit.

`:audit` re-evaluates user callbacks and is for diagnosis, never performance timing.
The default `Options(diagnostics=nothing)` records nothing and reads no clock.
"""
mutable struct DiagnosticLog
    level::Symbol
    emit::Bool
    max_events::Int
    events::Vector{Dict{String,Any}}
    dropped::Int
    mutex::ReentrantLock
    origin_ns::UInt64
    origin_utc::String
    process_id::Int
    producers::IdDict{Any,Int}
    iterations::IdDict{Any,Int}
end
function DiagnosticLog(;level=:summary,max_events=2000,emit=false)
    level in (:summary,:debug,:trace,:audit) || throw(ArgumentError("unknown diagnostic level"))
    max_events>0 || throw(ArgumentError("max_events must be positive"))
    DiagnosticLog(level,Bool(emit),Int(max_events),Dict{String,Any}[],0,ReentrantLock(),time_ns(),
        string(now(UTC)),getpid(),IdDict{Any,Int}(),IdDict{Any,Int}())
end
# Subsolver options are deep-copied; local trajectories must retain one synchronized sink.
Base.deepcopy_internal(log::DiagnosticLog,::IdDict)=log
_diagnostic_rank(level)=level===:summary ? 1 : level===:debug ? 2 : level===:trace ? 3 : 4
_diagnostic_enabled(log::DiagnosticLog,level)=_diagnostic_rank(log.level)>=_diagnostic_rank(level)
_logger_diagnostics(logger)=nothing
_solver_diagnostics(s)=_logger_diagnostics(s.logger)

"Lazy event payload: arguments are never evaluated when diagnostics are disabled."
macro ls_diagnostic(s,level,event,args...)
    quote
        local solver_for_diagnostic=$(esc(s))
        local diagnostic_log=_solver_diagnostics(solver_for_diagnostic)
        if diagnostic_log!==nothing && _diagnostic_enabled(diagnostic_log,$(esc(level)))
            _record_diagnostic!(diagnostic_log,solver_for_diagnostic,$(esc(event)),
                (;$(map(esc,args)...)),$(esc(level)))
        end
    end
end

function _diagnostic_value(x)
    x isa AbstractFloat && !isfinite(x) && return string(x)
    x isa Symbol && return string(x)
    x isa Union{NamedTuple,AbstractDict} && return Dict(string(k)=>_diagnostic_value(v) for (k,v) in pairs(x))
    x isa Union{Tuple,AbstractVector} && return [_diagnostic_value(v) for v in x]
    x isa Union{Nothing,Bool,Number,AbstractString} && return x
    string(x)
end
function _diagnostic_pool(pool)
    is_empty(pool) && return (present=false,feasible=false,score=nothing)
    (present=true,feasible=has_solution(pool),score=best_value(pool),
        configuration_score=get_value(best_config(pool)),size=length(pool.configurations))
end
function _diagnostic_cached(s)
    state=s.state
    current=state isa EmptyState ? nothing :
        (feasible=has_solution(state),violation=get_error(state),value=get_value(state),optimizing=_optimizing(state))
    (current=current,pool=hasproperty(s,:pool) ? _diagnostic_pool(s.pool) : nothing)
end
function _record_diagnostic!(log,s,event,data,level=:summary)
    record=lock(log.mutex) do
        # A deserialized remote sink has a separate clock origin and buffer.
        if log.process_id!=getpid()
            empty!(log.events);empty!(log.producers);empty!(log.iterations)
            log.process_id=getpid();log.origin_ns=time_ns();log.origin_utc=string(now(UTC));log.dropped=0
        end
        if length(log.events)>=log.max_events
            log.dropped+=1
            return nothing
        end
        logger=s.logger
        producer=get!(log.producers,logger,length(log.producers)+1)
        if haskey(data,:iteration_count)
            log.iterations[logger]=data.iteration_count
        elseif hasproperty(s,:iterations)
            log.iterations[logger]=iterations(s)
        end
        record=Dict("sequence"=>length(log.events)+1,"event"=>string(event),"level"=>string(level),
            "elapsed_ns"=>time_ns()-log.origin_ns,"process_id"=>getpid(),"worker_id"=>myid(),
            "thread_id"=>Threads.threadid(),"producer"=>producer,
            "iteration"=>get(log.iterations,logger,0),
            "cached"=>_diagnostic_value(_diagnostic_cached(s)),"data"=>_diagnostic_value(data))
        push!(log.events,record)
        record
    end
    log.emit && record!==nothing && _emit_diagnostic_event(record)
    nothing
end

function _emit_diagnostic_event(event)
    data=event["data"]
    truth=get(data,"truth",nothing)
    inconsistent=event["event"]=="consistency" && truth!==nothing &&
        get(truth,"available",false) &&
        (!get(truth,"score_matches",true) || !get(truth,"feasibility_matches",true))
    message="CBLS $(event["event"]) | iteration=$(event["iteration"]) | worker=$(event["worker_id"]) trajectory=$(event["producer"]) | t=$(round(event["elapsed_ns"]/1e9;digits=6))s"
    current=event["cached"]["current"];pool=event["cached"]["pool"]
    if current!==nothing
        phase=current["optimizing"] ? "optimization" : "satisfaction"
        message*=" | phase=$phase violation=$(current["violation"]) current_value=$(current["value"])"
    end
    pool!==nothing && get(pool,"present",false) &&
        (message*=" | pool_score=$(pool["score"]) pool_feasible=$(pool["feasible"])")
    haskey(data,"proposed_score") && (message*=" | proposed_score=$(data["proposed_score"])")
    haskey(data,"reason") && (message*=" reason=$(data["reason"])")
    if inconsistent
        @error "CBLS inconsistent stored result | reported=$(get(truth,"reported_score","unknown")) recomputed=$(get(truth,"normalized_score","unknown"))" sequence=event["sequence"] step=message truth
    elseif event["event"]=="consistency" && truth!==nothing && !get(truth,"available",false) && haskey(truth,"error")
        @warn "CBLS diagnostic recomputation failed" sequence=event["sequence"] step=message truth
    elseif event["level"]=="trace"
        @debug message _group=:cbls_trace sequence=event["sequence"] data
    elseif event["level"] in ("debug","audit")
        @debug message sequence=event["sequence"] cached=event["cached"] data
    else
        @info message sequence=event["sequence"] cached=event["cached"] data
    end
    nothing
end

"Independent callback recomputation for diagnosis; never writes solver caches."
function _diagnostic_truth(s)
    try
        is_empty(s.pool) && return (available=false,)
        values=deepcopy(best_values(s))
        workspace=copy(s.state.icn_computations)
        error=compute_costs(s.model,values,workspace)
        feasible=iszero(error)
        raw_objective=is_sat(s) ? nothing : compute_objective(s.model,collect(values))
        score=is_sat(s) || !feasible ? error : sense(s)*raw_objective
        (available=true,values=collect(values),violation=error,objective=raw_objective,
            normalized_score=score,reported_score=best_value(s),
            score_matches=isequal(score,best_value(s)),
            feasibility_matches=(has_solution(s)==feasible))
    catch exception
        (available=false,error=sprint(showerror,exception))
    end
end

"A copy of the diagnostic buffer, safe to inspect after concurrent work."
diagnostic_events(log::DiagnosticLog)=lock(()->deepcopy(log.events),log.mutex)

"Write structured diagnostics after solving. Clock origin is UTC, event durations monotonic."
function write_diagnostics(log::DiagnosticLog,path::AbstractString;overwrite=false)
    target=abspath(path)
    length(transcode(UInt16,target))+42<=240 || throw(ArgumentError("diagnostic path too long; choose a shorter root"))
    ispath(target) && !overwrite && throw(ArgumentError("diagnostic output already exists"))
    data=lock(log.mutex) do
        Dict("schema"=>"local-search-diagnostics/1","level"=>string(log.level),
            "origin_utc"=>log.origin_utc,"process_id"=>log.process_id,
            "events"=>deepcopy(log.events),"dropped_events"=>log.dropped,
            "max_events"=>log.max_events,"complete_trace"=>iszero(log.dropped))
    end
    mkpath(dirname(target));temporary=target*".tmp-"*string(time_ns())
    try
        open(temporary,"w") do io;JSON.print(io,data,2);end
        mv(temporary,target;force=overwrite)
    finally
        isfile(temporary) && rm(temporary)
    end
    target
end
export DiagnosticLog, diagnostic_events, write_diagnostics
