# Included inside LocalSearchSolversMetaStrategistExt.
function select_cost_update(policy,state)
    incremental=LS._has_incremental(state)
    policy==:runtime && return LS.RuntimeCostUpdate()
    policy==:auto && return incremental ? LS.IncrementalCostUpdate() : LS.FullCostUpdate()
    # Mixing a full update with stateful invariants can invalidate their caches.
    (policy==:incremental)==incremental || throw(ArgumentError("cost update policy contradicts initialized invariant contract"))
    incremental ? LS.IncrementalCostUpdate() : LS.FullCostUpdate()
end

function component_value(x,depth=0)
    x isa Union{Nothing,Bool,Symbol,String,Integer,AbstractFloat} && return x
    x isa Tuple && return map(v->component_value(v,depth+1),x)
    depth>8 && return (;status=:unknown,reason=:nested_component)
    excluded=(:description,:tabu_list,:index,:current,:last_restart,:resets,:pending,:refresh,:current_objective)
    names=filter(n->!(n in excluded),fieldnames(typeof(x)))
    if x isa AbstractArray || x isa AbstractDict
        return (;status=:unknown,reason=:mutable_configuration_requires_descriptor)
    end
    (;implementation=string(parentmodule(typeof(x)),'.',nameof(typeof(x))),
      type_configuration=Tuple(p isa Union{Bool,Symbol,Number} ? p : string(p) for p in typeof(x).parameters),
      parameters=NamedTuple{names}(Tuple(component_value(getfield(x,n),depth+1) for n in names)))
end
LS.strategy_descriptor(strategy)=component_value(strategy)
component_description(strategy)= (;declared=strategy.description,
    bound=NamedTuple{(:selection,:neighborhood,:depth,:acceptance,:restart,:tabu)}(
        map(LS.strategy_descriptor,(strategy.variable_selection,strategy.neighborhood,strategy.depths,
            strategy.acceptance,strategy.restart,strategy.tabu))))

# The registry is cold and weak: it prevents concurrent ownership without retaining solvers.
const solver_owners=WeakKeyDict{Any,Task}()
const prepared_owners=WeakKeyDict{Any,WeakRef}()
const solver_owners_lock=ReentrantLock()
function claim_solver!(s;unit=nothing)
    lock(solver_owners_lock) do
        owner=get(prepared_owners,s,nothing)
        owner!==nothing && owner.value!==nothing && owner.value!==unit &&
            throw(ArgumentError("solver belongs to a prepared unit; use its episode API or release it"))
        haskey(solver_owners,s) && throw(ArgumentError("solver already belongs to an active episode"))
        solver_owners[s]=current_task()
    end
end
function release_solver!(s)
    lock(solver_owners_lock) do; delete!(solver_owners,s); end
end
function assert_idle(s)
    lock(solver_owners_lock) do
        haskey(solver_owners,s) && throw(ArgumentError("suspend and join the active episode before changing its unit"))
    end
end
function LS._solve_lease(::ExecutionBuilder,s)
    claim_solver!(s)
    try
        return (s,LS._lease_model!(s.model))
    catch
        release_solver!(s); rethrow()
    end
end
function LS._solve_release(lease::Tuple{LS.AbstractSolver,LS.ModelLifecycle})
    LS._release_model!(lease[2]);release_solver!(lease[1]);nothing
end
function validate_context(ctx::ExecutionContext,s)
    ctx.frame.solver===s && ctx.state===s.state && ctx.model===s.model &&
        ctx.strategy===s.strategies && ctx.logger===s.logger && ctx.progress===s.progress_tracker ||
        throw(ArgumentError("prepared context bindings are stale; prepare or restore the unit again"))
    ctx.incremental==LS._has_incremental(s.state) || throw(ArgumentError("invariant contract changed; prepare again"))
    nothing
end
function with_context(f,ctx::ExecutionContext,s)
    trylock(ctx.lock) || throw(ArgumentError("context is already executing"))
    lease=nothing
    try
        validate_context(ctx,s)
        lease=LS._lease_model!(s.model,ctx.revision)
        ctx.sink===nothing || (ctx.sink.owner=current_task())
        f()
    finally
        lease===nothing || LS._release_model!(lease)
        unlock(ctx.lock)
    end
end
LS._run_prepared_loop!(ctx::ExecutionContext,s,stop,sat,iter,st)=
    with_context(()->LS._solve_while_loop!(s,stop,sat,iter,st,ctx),ctx,s)

"Owned local trajectory. Kernels are relinked on restoration; RNG belongs to the unit."
mutable struct PreparedUnit{S,R}
    solver::S
    rng::R
    builder::ExecutionBuilder
    context::Any
    baseline::Any
    lock::ReentrantLock
    stop::Threads.Atomic{Bool}
    receipts::Vector{NamedTuple}
    status::Symbol
    identity::String
    borrowed::Tuple
end
function with_rng(f,rng)
    outer=copy(Random.default_rng())
    copy!(Random.default_rng(),rng)
    try
        f()
    finally
        copy!(rng,Random.default_rng())
        copy!(Random.default_rng(),outer)
    end
end
function copy_unit_graph(graph,s,borrowed)
    shared=IdDict{Any,Any}(s=>s,s.model=>s.model,current_task()=>current_task())
    for object in borrowed;shared[object]=object;end
    hasproperty(graph,:sink) && graph.sink!==nothing && (shared[graph.sink.owner]=graph.sink.owner)
    Base.deepcopy_internal(graph,shared)
end
function own_kernel(kernel,s,sink,borrowed)
    anchors=IdDict{Any,Any}()
    for object in (s,s.model,s.state,s.strategies,s.logger,s.progress_tracker,sink,borrowed...)
        anchors[object]=object
    end
    Base.deepcopy_internal(kernel,anchors)
end
function unit_graph(u)
    s=u.solver
    # Preserve aliases across state, pool, strategy, observers and progress together.
    copy_unit_graph((;state=s.state,pool=LS._pool_snapshot(s),strategy=s.strategies,
        progress=s.progress_tracker,logger=s.logger,iterations=LS.iterations(s),options=s.options,
        kernel=u.context.kernel,sink=u.context.sink),s,u.borrowed)
end
function LS.prepare_unit(s;kwargs...)
    lock(solver_owners_lock) do
        assert_idle(s)
        owner=get(prepared_owners,s,nothing)
        owner!==nothing && owner.value!==nothing && throw(ArgumentError("solver already owns a prepared unit"))
        lock(s.model.lifecycle.lock) do
            s.model.lifecycle.readers==0 || throw(ArgumentError("model still in use"))
            prepare_owned_unit(s;kwargs...)
        end
    end
end
function prepare_owned_unit(s;builder=LS.execution_builder(),seed=0,initialize=true,borrowed=())
    assert_idle(s)
    LS.get_option(s,Val(:dynamic)) && throw(ArgumentError("owned units require dynamic=false"))
    LS.get_option(s,Val(:threads))==1 || throw(ArgumentError("prepare one trajectory per unit; set process_threads_map=Dict(1=>1)"))
    length(LS.get_option(s,Val(:process_threads_map)))==1 || throw(ArgumentError("prepare units inside each process"))
    rng=Random.Xoshiro(seed)
    with_rng(rng) do
        initialize && LS._init!(s)
    end
    LS.set_option!(s,Val(:execution_builder),builder)
    ctx=with_rng(()->builder(s;borrowed),rng)
    u=PreparedUnit(s,rng,builder,ctx,nothing,ReentrantLock(),Threads.Atomic{Bool}(false),
        NamedTuple[last(builder.last_decisions).receipt],:prepared,last(builder.last_decisions).receipt.unit,Tuple(borrowed))
    prepared_owners[s]=WeakRef(u)
    u.baseline=LS.snapshot_unit(u)
    u
end
function idle_unit(f,u::PreparedUnit)
    trylock(u.lock) || throw(ArgumentError("unit is running; suspend and join first"))
    try
        u.status==:released && throw(ArgumentError("unit has been released"))
        lock(solver_owners_lock) do
            assert_idle(u.solver)
            lock(u.solver.model.lifecycle.lock) do
                u.solver.model.lifecycle.readers==0 || throw(ArgumentError("model still in use by another episode"))
                f()
            end
        end
    finally
        unlock(u.lock)
    end
end
function LS.snapshot_unit(u::PreparedUnit)
    idle_unit(u) do
        validate_context(u.context,u.solver)
        u.context.revision==LS.model_revision(u.solver.model) || throw(ArgumentError("stale unit"))
        (;schema="local-unit/1",model=u.solver.model,revision=u.context.revision,
          graph=unit_graph(u),rng=copy(u.rng),receipt=last(u.receipts),template=u.builder.template,
          execution_key=u.builder.template.semantic_key,mode=u.builder.mode)
    end
end
function relink!(u;restored=nothing)
    LS.set_option!(u.solver,Val(:execution_builder),u.builder)
    u.context=with_rng(()->u.builder(u.solver;unit_id=u.identity,restored,borrowed=u.borrowed),u.rng)
    push!(u.receipts,last(u.builder.last_decisions).receipt)
    u.status=:prepared; u.stop[]=false
    u
end
function LS.restore_unit!(u::PreparedUnit,snapshot)
    idle_unit(u) do
        snapshot.schema=="local-unit/1" || throw(ArgumentError("unknown unit snapshot"))
        snapshot.model===u.solver.model && snapshot.revision==LS.model_revision(u.solver.model) ||
            throw(ArgumentError("snapshot model or revision differs; reconfigure instead"))
        snapshot.execution_key==u.builder.template.semantic_key && snapshot.mode==u.builder.mode ||
            throw(ArgumentError("snapshot execution differs; reconfigure instead"))
        snapshot.template===u.builder.template || throw(ArgumentError("snapshot factories differ; reconfigure instead"))
        g=copy_unit_graph(snapshot.graph,u.solver,u.borrowed);s=u.solver
        s.state=g.state;s.strategies=g.strategy;s.progress_tracker=g.progress;s.logger=g.logger;s.options=g.options
        LS._replace_pool!(s,g.pool); LS._iterations!(s,g.iterations)
        copy!(u.rng,snapshot.rng)
        relink!(u;restored=(;kernel=g.kernel,sink=g.sink,mode=snapshot.receipt.execution.effective))
    end
end
LS.reset_unit!(u::PreparedUnit)=LS.restore_unit!(u,u.baseline)
LS.unit_receipt(u::PreparedUnit)=last(u.receipts)
"Request a stop at the next iteration boundary. Join the running task before restore/edit."
LS.suspend!(u::PreparedUnit)=(u.stop[]=true;nothing)
function LS.resume_unit!(u::PreparedUnit)
    idle_unit(u) do
        validate_context(u.context,u.solver)
        u.context.revision==LS.model_revision(u.solver.model) || throw(ArgumentError("stale unit"))
        u.stop[]=false;u.status=:prepared;u
    end
end
function LS.release_unit!(u::PreparedUnit)
    idle_unit(u) do
        delete!(prepared_owners,u.solver);u.status=:released;u.solver
    end
end
function episode_loop!(ctx,s,stop,n)
    completed=0;found=false
    LS.is_sat(s) && LS._solution_limit_reached(s) && return (;iterations=0,found=true,interrupted=stop[])
    for _ in 1:n
        stop[] && break
        found=LS._context_step!(ctx,s)
        completed+=1
        LS._iterations!(s,LS.iterations(s)+1)
        found && LS.is_sat(s) && break
    end
    (;iterations=completed,found,interrupted=stop[])
end
function LS.run_episode!(u::PreparedUnit;iterations::Integer)
    iterations>=0 || throw(ArgumentError("negative episode budget"))
    trylock(u.lock) || throw(ArgumentError("unit is already running"))
    claimed=false
    try
        u.status==:released && throw(ArgumentError("unit has been released"))
        claim_solver!(u.solver;unit=u);claimed=true
        u.status=:running
        result=with_rng(u.rng) do
            with_context(u.context,u.solver) do
                episode_loop!(u.context,u.solver,u.stop,iterations)
            end
        end
        u.status=result.interrupted ? :suspended : :completed
        result
    catch
        u.status==:released || (u.status=:failed)
        rethrow()
    finally
        claimed && release_solver!(u.solver)
        unlock(u.lock)
    end
end
function LS.reconfigure_unit!(u::PreparedUnit;model=u.solver.model,strategy=deepcopy(u.baseline.graph.strategy),
        builder=u.builder,seed=0)
    idle_unit(u) do
        # idle_unit guards the old model; retain the new model's lock throughout
        # initialization too, so an edit cannot slip between validation and binding.
        lock(model.lifecycle.lock) do
            model.lifecycle.readers==0 || throw(ArgumentError("model still leased"))
            u.solver.model=model;u.solver.strategies=strategy;u.builder=builder
            Random.seed!(u.rng,seed)
            with_rng(u.rng) do; LS._init!(u.solver); end
            relink!(u)
            u.baseline=LS.snapshot_unit(u)
            u
        end
    end
end
"Collect every stopped local unit; remote processes export their own result separately."
function LS.take_strategy_events!(s::LS.AbstractSolver)
    assert_idle(s)
    units=hasproperty(s,:subs) ? (s,s.subs...) : (s,)
    Tuple((;unit=x.meta_local_id,data=LS.take_strategy_events!(LS.get_option(x,Val(:execution_builder))))
        for x in units if LS.get_option(x,Val(:execution_builder)) isa ExecutionBuilder)
end
LS._strategy_run_records(::ExecutionBuilder,s)=LS.take_strategy_events!(s)
