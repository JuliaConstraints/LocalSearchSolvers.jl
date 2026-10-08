module LocalSearchSolversMetaStrategistExt
import LocalSearchSolvers as LS
import MetaStrategist as MS
import Random

struct BindComponent{K,V}
    value::V
end
(b::BindComponent{K})(bindings) where K = (bindings[K]=b.value; nothing)
function LS.strategy_catalog()
    c=MS.PhaseCatalog()
    add(role,impl,f;kw...)=MS.register_phase!(c,MS.PhaseDefinition(role,impl,f;writes=(role,),kw...))
    add(:selection,:worst,(p,m)->BindComponent{:selection,LS.WorstVariableSelector}(LS.WorstVariableSelector()))
    add(:neighborhood,:assign_swap,(p,m)->BindComponent{:neighborhood,LS.AssignSwapNeighborhood}(LS.AssignSwapNeighborhood()))
    add(:depth,:fixed,(p,m)->begin
        x=LS.DepthSchedule(p.values...); BindComponent{:depth,typeof(x)}(x)
    end)
    add(:acceptance,:best_improving,(p,m)->BindComponent{:acceptance,LS.BestImprovingAcceptance}(LS.BestImprovingAcceptance()))
    add(:tabu,:keen,(p,m)->begin
        tenure=get(p,:tenure,min(LS.length_vars(m)÷2,10))
        x=LS.tabu(tenure,get(p,:pick,tenure÷2)); BindComponent{:tabu,typeof(x)}(x)
    end)
    # The restart phase reads the exact tabu created by this unit, preserving its alias.
    add(:restart,:universal,(p,m)->bindings->begin
        bindings[:restart]=LS.restart(bindings[:tabu],Val(:universal)); nothing
    end;dependencies=(:tabu,),reads=(:tabu,))
    defaults=Dict(:selection=>MS.PhaseChoice(:worst),:neighborhood=>MS.PhaseChoice(:assign_swap),
        :depth=>MS.PhaseChoice(:fixed;values=(0,1)),:acceptance=>MS.PhaseChoice(:best_improving),
        :tabu=>MS.PhaseChoice(:keen),:restart=>MS.PhaseChoice(:universal))
    c, MS.StrategyProfile(:cbls_compatibility,"1",defaults)
end
function LS.materialize_strategy(ir::MS.ExecutionIR, model;mode=:generated,budget=MS.default_preparation_service())
    prepared=MS.prepare_strategy(ir,model;mode,budget)
    bindings=Dict{Symbol,Any}()
    MS.execute!(prepared.kernel,bindings)
    expected=Set((:selection,:neighborhood,:depth,:acceptance,:restart,:tabu))
    Set(keys(bindings))==expected || throw(ArgumentError("CBLS binding contract needs exactly $expected"))
    LS.MetaStrategy(bindings[:selection],bindings[:neighborhood],bindings[:depth],
        bindings[:acceptance],bindings[:restart],bindings[:tabu],
        (;key=ir.semantic_key,plan=MS.strategy_snapshot(ir),
          provenance=MS.source_inventory((LS,MS))))
end

struct SearchStep{M,S,L,T,C}
    model::M
    state::S
    logger::L
    strategy::T
    cost_update::C
end
@inline function (step::SearchStep)(frame)
    frame.found=LS._step!(frame.solver,step.model,step.state,step.logger,step.strategy,step.cost_update)
    nothing
end
mutable struct ImprovementObserver{S}
    sink::MS.EventBuffer
    state::S
    best::Tuple{Float64,Float64}
end
function (o::ImprovementObserver)(frame)
    error=LS.get_error(o.state)
    objective=LS._optimizing(o.state) ? LS.get_value(o.state) : Inf
    score=(Float64(error),Float64(objective))
    if score<o.best
        o.best=score
        MS.observe!(o.sink,:improvement;iteration=LS.iterations(frame.solver),error,objective,
            values=collect(LS.get_values(o.state)))
    end
    nothing
end
struct DiagnosticObserver{S}
    sink::MS.EventBuffer
    state::S
end
function (o::DiagnosticObserver)(frame)
    MS.observe!(o.sink,:iteration;iteration=LS.iterations(frame.solver),error=LS.get_error(o.state))
end
struct ExecutionContext{K,F,P,S}
    kernel::K
    frame::F
    progress::P
    state::S
    model::LS._Model
    strategy::LS.MetaStrategy
    logger::LS.AbstractLogger
    revision::UInt64
    incremental::Bool
    lock::ReentrantLock
    sink::Union{Nothing,MS.EventBuffer}
end
@inline function LS._context_step!(context::ExecutionContext,s)
    context.frame.found=false
    MS.execute!(context.kernel,context.frame)
    context.frame.found
end
@inline LS._context_progress!(context::ExecutionContext,s,iter) =
    LS._update_iteration_progress!(context.progress,context.state,iter)

mutable struct ExecutionBuilder{T}
    template::T
    mode::Symbol
    telemetry::Symbol
    budget::MS.GenerationBudget
    lock::ReentrantLock
    buffers::Vector{MS.EventBuffer}
    max_buffers::Int
    last_decisions::Vector{NamedTuple}
    provenance::Tuple
    model_reference::NamedTuple
end
function Base.deepcopy_internal(builder::ExecutionBuilder,dict::IdDict)
    haskey(dict,builder) && return dict[builder]
    copy=ExecutionBuilder(builder.template,builder.mode,builder.telemetry,
        Base.deepcopy_internal(builder.budget,dict),ReentrantLock(),MS.EventBuffer[],
        builder.max_buffers,NamedTuple[],builder.provenance,builder.model_reference)
    dict[builder]=copy
    copy.template=Base.deepcopy_internal(builder.template,dict)
    copy
end
function LS.execution_builder(;mode=:generated,telemetry=:none,budget=MS.default_preparation_service(),max_buffers=64,cost_update=:auto,
        model_reference=(;),provenance=MS.source_inventory((LS,MS)))
    mode in (:generated,:typed,:reference) || throw(ArgumentError("unknown execution mode"))
    cost_update in (:auto,:runtime,:full,:incremental) || throw(ArgumentError("unknown cost update policy"))
    telemetry in (:none,:improvements,:diagnostic) || throw(ArgumentError("unknown telemetry profile"))
    max_buffers>0 || throw(ArgumentError("max_buffers must be positive"))
    MS.canonical_value(model_reference);MS.canonical_value(Tuple(provenance))
    c=MS.PhaseCatalog()
    MS.register_phase!(c,MS.PhaseDefinition(:step,:cbls,
        (p,ctx)->SearchStep(ctx.solver.model,ctx.solver.state,ctx.solver.logger,ctx.solver.strategies,
            select_cost_update(p.policy,ctx.solver.state));
        reads=(:search,),writes=(:search,:found)))
    defaults=Dict(:step=>MS.PhaseChoice(:cbls;policy=cost_update)); roots=[:step]
    if telemetry!=:none
        factory=telemetry==:improvements ?
            ((p,ctx)->ImprovementObserver(ctx.sink,ctx.solver.state,
                (Float64(LS.get_error(ctx.solver.state)),LS._optimizing(ctx.solver.state) ? Float64(LS.get_value(ctx.solver.state)) : Inf))) :
            ((p,ctx)->DiagnosticObserver(ctx.sink,ctx.solver.state))
        MS.register_phase!(c,MS.PhaseDefinition(:observe,telemetry,factory;
            dependencies=(:step,),reads=(:search,)))
        defaults[:observe]=MS.PhaseChoice(telemetry); push!(roots,:observe)
    end
    ir=MS.resolve_strategy(c,MS.StrategyProfile(:cbls_execution,"1",defaults);roots,inputs=(:search,))
    ExecutionBuilder(MS.strategy_template(ir),mode,telemetry,MS.preparation_service(budget),ReentrantLock(),MS.EventBuffer[],max_buffers,NamedTuple[],Tuple(provenance),model_reference)
end
"Use an independently resolved iteration plan. Factories receive (solver, sink)."
function LS.execution_builder(ir::MS.ExecutionIR;mode=:generated,budget=MS.default_preparation_service(),max_buffers=64,
        model_reference=(;),provenance=MS.source_inventory((LS,MS,(parentmodule(typeof(p.definition.factory)) for p in ir.phases)...)))
    mode in (:reference,:typed,:generated) && max_buffers>0 || throw(ArgumentError("invalid builder options"))
    available=Set(ir.inputs)
    for phase in ir.phases
        setdiff!(available,phase.definition.invalidates)
        union!(available,phase.definition.writes)
    end
    :search in ir.inputs && issubset(Set((:search,:found)),available) ||
        throw(ArgumentError("CBLS iteration plan requires search input and search/found outputs"))
    MS.canonical_value(model_reference);MS.canonical_value(Tuple(provenance))
    ExecutionBuilder(MS.strategy_template(ir),mode,:none,MS.preparation_service(budget),ReentrantLock(),MS.EventBuffer[],max_buffers,NamedTuple[],Tuple(provenance),model_reference)
end
function LS._validate_execution_builder(builder::ExecutionBuilder,s)
    LS.get_option(s,Val(:dynamic)) && throw(ArgumentError("prepared execution requires dynamic=false; use the historical loop for dynamic models"))
    nothing
end

# Type descriptions are immutable metadata. Print each distinct evaluator type
# once per receipt, retaining the same per-constraint order and identity bytes.
function evaluator_types(model)
    descriptions=Dict{Type,String}()
    Tuple(get!(descriptions,typeof(c.f)) do
        string(typeof(c.f))
    end for c in LS.get_constraints(model))
end
function (builder::ExecutionBuilder)(s;unit_id=string(getpid(),':',s.meta_local_id,':',time_ns()),restored=nothing,borrowed=())
    LS.get_option(s,Val(:dynamic)) && throw(ArgumentError("prepared execution requires dynamic=false; use the historical loop for dynamic models"))
    lock(builder.lock) do
        length(builder.last_decisions)<builder.max_buffers || throw(ArgumentError("drain take_strategy_events! before preparing further trajectories"))
        sink=restored===nothing ? (builder.telemetry==:none ? nothing : MS.EventBuffer()) : restored.sink
        if restored!==nothing && sink!==nothing
            empty!(sink.records);sink.dropped=0;sink.started_ns=time_ns();sink.owner=current_task()
        end
        isnothing(sink) || push!(builder.buffers,sink)
        builder.budget=MS.preparation_service(builder.budget)
        prepared=restored===nothing ? MS.instantiate_strategy(builder.template,(solver=s,sink=sink);mode=builder.mode,budget=builder.budget,
            execution_type=LS.PreparedStepState{typeof(s)}) :
            MS.PreparedStrategy(restored.kernel,builder.template.semantic_key,builder.template.shape_key,
                restored.mode,"restored owned phase graph at an iteration boundary")
        kernel=restored===nothing ? own_kernel(prepared.kernel,s,sink,borrowed) : prepared.kernel
        receipt=MS.preparation_receipt(unit=unit_id,component=component_description(s.strategies),
            execution=(;key=prepared.semantic_key,shape=prepared.shape_key,plan=builder.template.snapshot,
                requested=builder.mode,effective=prepared.mode,reason=prepared.reason),
            model_revision=LS.model_revision(s.model),provenance=builder.provenance,
            resources=(;process=getpid(),threads=Threads.nthreads(),
                model=(;scope=isempty(builder.model_reference) ? :process_local : :externally_identified,
                    reference=builder.model_reference,identity=string(objectid(s.model)),
                    evaluator_types=evaluator_types(s.model)),
                cost_contract=LS._has_incremental(s.state) ? :incremental : :full))
        push!(builder.last_decisions,(mode=prepared.mode,reason=prepared.reason,
            semantic_key=prepared.semantic_key,shape_key=prepared.shape_key,receipt=MS.receipt_snapshot(receipt)))
        ExecutionContext(kernel,LS.PreparedStepState(s,false),s.progress_tracker,s.state,
            s.model,s.strategies,s.logger,LS.model_revision(s.model),LS._has_incremental(s.state),ReentrantLock(),sink)
    end
end
"Drain only after all trajectories have stopped; retains the worker generation quota."
function LS.take_strategy_events!(builder::ExecutionBuilder)
    lock(builder.lock) do
        result=(events=Tuple(MS.events(b) for b in builder.buffers),
            dropped=Tuple(b.dropped for b in builder.buffers),decisions=Tuple(builder.last_decisions),
            recycle_requested=builder.budget.recycle_requested)
        empty!(builder.buffers); empty!(builder.last_decisions)
        result
    end
end
include("strategy_units.jl")
end
