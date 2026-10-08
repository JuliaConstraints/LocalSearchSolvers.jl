module PerformanceContractTests
using Test
using Dictionaries
using Random
using Constraints
import LocalSearchSolvers as LS
include("../perf/tabu_scenarios.jl")
include("../perf/public_commit_scenarios.jl")

mutable struct CommitIdentityProbe
    expected::Any
    observations::Vector{Bool}
end
function LS.value_after(move::LS.MetaMove{T,CommitIdentityProbe}, values, variable) where T
    push!(move.provenance.observations,move===move.provenance.expected)
    index=LS._replacement_index(move,variable)
    iszero(index) ? values[variable] : move.replacements[index]
end

@testset "Initialization preserves independent configurations and cost oracles" begin
    for n in (0,1,8,32), seed in 1:4
        model=LS.model()
        foreach(_->LS.variable!(model,LS.domain(0:7)),1:n)
        for width in unique((0,min(1,n),min(4,n),n))
            LS.constraint!(model,(values;X)->Float64(sum(values;init=0)>7),1:width)
        end
        LS.objective!(model,values->sum(values;init=0))
        model=LS.specialize(model)
        external=Matrix{Float64}(undef,n,32)
        Random.seed!(seed)
        reference=LS.Configuration(model,external)
        Random.seed!(seed)
        state=LS.state(model)
        @test collect(LS.get_values(state))==collect(reference.values)
        @test state.configuration.solution==reference.solution
        @test state.configuration.value==reference.value
        @test state.configuration.values!==reference.values
        other=LS.state(model)
        @test state.constraint_input!==other.constraint_input
        @test state.neighborhood.changes!==other.neighborhood.changes
    end
end

function committed_cycles(solver, context, moves, repetitions)
    for _ in 1:repetitions, move in moves
        affected=LS._commit!(context,move)
        LS._compute_committed!(solver;cons_lst=affected)
    end
    nothing
end
function full_cycles(solver, context, moves, repetitions)
    for _ in 1:repetitions, move in moves
        affected=LS._commit!(context,move)
        LS._compute!(solver;cons_lst=affected)
    end
    nothing
end

@testset "Solver cost barriers preserve satisfaction and objective after commits" begin
    for incremental in (false,true)
        model=LS.model()
        foreach(_->LS.variable!(model,LS.domain(0:3)),1:2)
        evaluator=incremental ? Constraints.bind_error(Constraints.make_error(:sum);op=<=,val=3) :
            ((values;X)->Float64(sum(values)>3))
        LS.constraint!(model,evaluator,1:2)
        LS.objective!(model,sum)
        solver=LS.solver(model;options=LS.Options(dynamic=false,iteration=1,
            print_level=:silent,log_mode=:silent,log_to_file=false,progress_mode=:none,
            process_threads_map=Dict(1=>1)))
        LS._init!(solver)
        context=LS._search_context(solver)
        scope=LS.MetaVariable(:pair,1:2)
        moves=(LS.MetaMove(scope,[1,1]),LS.MetaMove(scope,[2,2]))
        cycles=incremental ? committed_cycles : full_cycles
        cycles(solver,context,moves,1)
        @test LS.get_error(solver)==1.0
        @test !LS.has_solution(solver.state)
        affected=LS._commit!(solver,first(moves))
        solved=incremental ? LS._compute_committed!(solver;cons_lst=affected) :
            LS._compute!(solver;cons_lst=affected)
        @test solved===true
        @test LS.get_error(solver)==0.0
        @test solver.state.configuration.value==2.0
        @test LS.has_solution(solver.state)
        cycles(solver,context,moves,128)
        @test (@allocated cycles(solver,context,moves,128))<=128
        @test LS.get_error(solver)==1.0
        @test collect(LS.get_values(solver))==[2,2]
    end
end

@testset "Union reduction covers empty, repeated and abstract types" begin
    @test LS._to_union(())===Union{}
    @test LS._to_union(Int)===Int
    @test LS._to_union(fill(Int,128))===Int
    @test LS._to_union((Int,Float64,Int))===Union{Int,Float64}
    @test LS._to_union(Set([Integer,Int,Float64]))===Union{Integer,Float64}
    @test LS._to_union((Vector,Vector{Int}))===Vector
end

function objective_allocations(context, move)
    LS._candidate_objective(context, move, 1)
    @allocated LS._candidate_objective(context, move, 1)
end

function proposal_allocations(context,strategy)
    LS._best_proposal!(context,1,strategy)
    @allocated LS._best_proposal!(context,1,strategy)
end

@testset "Mixed assignment/swap scans allocate per neighborhood, not per candidate" begin
    allocation_counts=Int[]
    for n in (4,32,106)
        model=LS.model()
        foreach(_->LS.variable!(model,LS.domain(0:n)),1:n)
        LS.constraint!(model,(x;X)->1.0,1:n)
        LS.objective!(model,sum)
        strategy=LS.MetaStrategy(model;acceptance=LS.GreedyPlateauAcceptance(guide_infeasible=false),
            tabu=LS.tabu(),restart=LS.restart(nothing,Val(:random);rp=0.))
        solver=LS.solver(model;strategies=strategy,options=LS.Options(
            dynamic=false,iteration=1,print_level=:silent,log_mode=:silent,
            log_to_file=false,progress_mode=:none,process_threads_map=Dict(1=>1)))
        LS._init!(solver)
        context=LS._search_context(solver)
        expected_values=Int[];expected_swaps=Int[]
        for depth in strategy.depths
            request=LS.NeighborhoodRequest(context,1,depth,nothing)
            for move in LS.generate_moves(strategy.neighborhood,request)
                if move isa LS.AssignMove
                    push!(expected_values,move.value)
                else
                    push!(expected_swaps,move.second)
                end
            end
        end
        move,rank=LS._best_proposal!(context,1,strategy)
        @test rank==(1.0,Inf)
        workspace=LS._neighborhood_workspace(context.state)
        @test workspace.best_values==expected_values
        @test workspace.best_swaps==expected_swaps
        @test move isa LS.AssignMove || move isa LS.SwapMove
        proposal_allocations(context,strategy)
        push!(allocation_counts,proposal_allocations(context,strategy))
        @test last(allocation_counts)<=1024
    end
    @test maximum(allocation_counts)-minimum(allocation_counts)<=128
end

@testset "Concrete model metadata and objective kernel" begin
    model=LS.model()
    @test @inferred(LS.sense(model)) == 1
    @test @inferred(LS._max_vars(model)) == 0
    foreach(_ -> LS.variable!(model,LS.domain(1:4)),1:2)
    LS.objective!(model,sum)
    solver=LS.solver(model;options=LS.Options(iteration=1,print_level=:silent,
        log_mode=:silent,progress_mode=:none,log_to_file=false,
        process_threads_map=Dict(1=>1)))
    LS._init!(solver)
    context=LS._search_context(solver)
    for move in (LS.AssignMove(1,4),LS.SwapMove(1,2))
        expected=sum(LS.value_after(move,LS.get_values(solver),i) for i in 1:2)
        @test @inferred(LS._candidate_objective(context,move,1)) == expected
        @test objective_allocations(context,move) == 0
        LS.sense!(context.model,Val(:max))
        @test @inferred(LS._candidate_objective(context,move,1)) == -expected
        LS.sense!(context.model,Val(:min))
    end
    @test @inferred(LS.sense(context.model)) == 1
end

@testset "Integer universal restart preserves its sequence" begin
    @test [LS._universal_restart_length(n) for n in 1:15] ==
        [1, 1, 2, 1, 1, 2, 4, 1, 1, 2, 1, 1, 2, 4, 8]
    @test all(LS._universal_restart_length(n) == LS.oeis(n, :A182105)
        for n in 1:100_000)
    @test LS._universal_restart_length(typemax(Int)) == one(Int) << (8sizeof(Int) - 2)
    @test LS._universal_restart_length(typemax(Int) - 1) == one(Int) << (8sizeof(Int) - 3)
    @test_throws ArgumentError LS._universal_restart_length(0)
    @test_throws ArgumentError LS._universal_restart_length(-1)
    old = LS.RestartSequence(n -> LS.oeis(n, :A182105))
    new = LS.restart(nothing, Val(:universal))
    @test all(LS.check_restart!(old) == LS.check_restart!(new) for _ in 1:100_000)
    @test (old.index, old.current, old.last_restart) ==
        (new.index, new.current, new.last_restart)
    @test @inferred(LS._universal_restart_length(127)) == 64
end

@testset "Tabu decay visits every entry exactly once" begin
    for count in 1:20, expired in 1:count, compacted in (false,true)
        strategy=LS.tabu(4,2)
        table=LS.tabu_list(strategy)
        compacted && filter!(_->false,table)
        for i in 1:count
            set!(table,i,i<=expired ? 1 : 3)
        end
        expected=Dict(k=>v-1 for (k,v) in pairs(table) if v!=1)
        LS.decay_tabu!(strategy)
        @test Dict(pairs(table)) == expected
    end
    generic=Dict(1=>1,2=>3,3=>0)
    @test LS._decay_tabu_entries!(generic) === nothing
    @test generic==Dict(2=>2,3=>-1)
end

@testset "Integer tabu fast paths preserve ordering, holes and nonpositive durations" begin
    for count in 0:16,variant in 1:6
        strategy=LS.tabu(4,2);table=LS.tabu_list(strategy)
        for id in 1:count;set!(table,id,mod(id+variant,6)-1);end
        for id in 1:4:count;delete!(table,id);end
        for step in 1:8
            before=collect(pairs(table))
            expected=[key=>remaining-1 for (key,remaining) in before if remaining!=1]
            @test LS.decay_tabu!(strategy)===nothing
            @test collect(pairs(table))==expected
            @test collect(keys(table))==first.(expected)
            iseven(step) && LS.insert_tabu!(strategy,step,:pick)
        end
        @test LS.empty_tabu!(strategy)===table
        @test isempty(table)
        @test LS.empty_tabu!(strategy)===table
        LS.insert_tabu!(strategy,1,:tabu)
        @test LS.tabu_value(strategy,1)==4
    end
    for clock in (:accepted,:proposal)
        strategy=LS.EventTabu(4;selected_tenure=2,clock)
        LS.insert_tabu!(strategy,1,Val(:tabu))
        LS._advance_proposal_tabu!(strategy,:rejected)
        @test LS.tabu_value(strategy,1)==(clock==:accepted ? 4 : 3)
        LS._advance_proposal_tabu!(strategy,:accepted)
        @test LS.tabu_value(strategy,1)==(clock==:accepted ? 3 : 2)
    end
end

@testset "Empty and nonexpiring integer tabu maintenance does not allocate per step" begin
    for factory in (tabu_decay_case,tabu_empty_case)
        case=factory(Dict());fixture=case.prepare()
        for _ in 1:2;@test case.verify(fixture,case.operation(fixture));end
        @test (@allocated case.operation(fixture))<=128
        @test case.verify(fixture,case.operation(fixture))
    end
end

@testset "Budget storage preserves integer and real limits" begin
    for limit in ((false,12),(true,12),(false,12.5),(true,Inf))
        options=LS.Options(iteration=limit,print_level=:silent)
        @test LS.get_option(options,Val(:iteration))===limit
        LS.set_option!(options,Val(:iteration),limit)
        @test LS.get_option(options,Val(:iteration))===limit
    end
end

@testset "Public block commits retain extension dispatch, metadata and atomic scores" begin
    for incremental in (false,true),dynamic in (false,true),T in (Int,Float64)
        # Frozen sum invariants require typed values; dynamic models exercise
        # the original full-cost evaluator on their Any-valued input instead.
        dynamic && incremental && continue
        model=LS.model()
        foreach(_->LS.variable!(model,LS.domain(T.(0:3))),1:4)
        evaluator=incremental ? Constraints.bind_error(Constraints.make_error(:sum);op=<=,val=3) :
            ((values;X)->Float64(sum(values)>3))
        LS.constraint!(model,evaluator,1:4);LS.objective!(model,sum)
        solver=LS.solver(model;options=LS.Options(;dynamic,iteration=1,
            print_level=:silent,log_mode=:silent,log_to_file=false,progress_mode=:none,
            process_threads_map=Dict(1=>1)))
        LS._init!(solver)
        scope=LS.MetaVariable(:block,1:4)
        probes=[CommitIdentityProbe(nothing,Bool[]) for _ in 1:3]
        moves=(LS.MetaMove(scope,T[0,0,0,0];provenance=probes[1]),
            LS.MetaMove(scope,[4,2],T[2,2];provenance=probes[2]),
            LS.MetaMove(scope,[2,4],T[0,0];provenance=probes[3]))
        for (probe,move) in zip(probes,moves);probe.expected=move;end
        for _ in 1:16,move in moves
            affected=LS._commit!(solver,move)
            @test affected===LS._neighborhood_workspace(solver.state).affected_constraints
            @test affected==[1]
            incremental ? LS._compute_committed!(solver;cons_lst=affected) :
                LS._compute!(solver;cons_lst=affected)
            values=collect(LS.get_values(solver));expected=Float64(sum(values)>3)
            @test LS.get_error(solver)==expected
            @test solver.state.configuration.solution==iszero(expected)
            @test solver.state.configuration.value==(iszero(expected) ? sum(values) : expected)
            @test all(iszero,values[[1,3]])
        end
        @test all(probe->!isempty(probe.observations) && all(probe.observations),probes)
        @test all(iszero,LS.get_values(solver))
    end
end

@testset "Public integer block commits keep the bounded metadata-boxing cost" begin
    for incremental in (false,true)
        case=public_commit_case(Dict("incremental"=>incremental));fixture=case.prepare()
        for _ in 1:2;@test case.verify(fixture,case.operation(fixture));end
        @test (@allocated case.operation(fixture))<=34_816
        @test case.verify(fixture,case.operation(fixture))
    end
end

function matrix_distance(a,b)
    matrix=zeros(Int,length(a)+1,length(b)+1)
    matrix[:,1]=0:length(a)
    matrix[1,:]=0:length(b)
    for i in 1:length(a), j in 1:length(b)
        matrix[i+1,j+1]=min(matrix[i,j+1]+1,matrix[i+1,j]+1,matrix[i,j]+(a[i]!=b[j]))
    end
    matrix[end,end]
end

@testset "Owned edit-distance buffers and cut reduction" begin
    rng=MersenneTwister(93)
    workspace=LS.NeighborhoodWorkspace(Int,LS.model())
    for n in (0,1,2,7,16,32), m in (0,1,2,7,16,32)
        a=rand(rng,1:4,n);b=rand(rng,1:4,m)
        @test LS._sequence_edit_distance!(workspace,a,b)==matrix_distance(a,b)
    end
    for n in (2,4,8), seed in 1:4
        graph=randn(rng,n,n)
        values=[fill(-1,n÷2);fill(1,n÷2);0]
        capacities=sort!([graph[i,j] for i in 1:n for j in 1:n if values[i]<0<values[j]])
        for k in (0,1,length(capacities))
            # Vector and view reductions may group finite Float64 additions
            # differently. Preserve exact tests for NaN/Inf/signed zero below.
            @test isapprox(LS.o_mincut(graph,values;interdiction=k),sum(capacities[1:end-k]);
                rtol=8eps(Float64),atol=8eps(Float64)*sum(abs,capacities))
        end
    end
    for value in (NaN,Inf,-Inf,-0.0)
        @test isequal(LS.o_mincut(fill(value,2,2),[-1,1,0]),sum([value]))
    end
end

struct OwnerSelector <: LS.AbstractVariableSelector
    owner::Base.RefValue{Any}
end
LS.select_target(selector::OwnerSelector,solver)=(selector.owner[]=solver;1)
@testset "Custom selectors retain the solver owner" begin
    owner=Ref{Any}(nothing);selector=OwnerSelector(owner)
    model=LS.model();LS.variable!(model,LS.domain(1:2))
    s=LS.solver(model;options=LS.Options(print_level=:silent,log_mode=:silent,progress_mode=:none))
    @test LS._select_target(selector,s,nothing,nothing)==1
    @test owner[]===s
end
@testset "Dense selector preserves exclusions, ties and RNG" begin
    for n in (1, 2, 16, 48), seed in 1:20
        model = LS.model()
        foreach(_ -> LS.variable!(model, LS.domain(0:1)), 1:n)
        LS.constraint!(model, (x; X) -> max(0, n ÷ 2 - sum(x)), 1:n)
        solver = LS.solver(model; options = LS.Options(
            iteration = 1, print_level = :silent, log_mode = :silent,
            log_to_file = false, progress_mode = :none, process_threads_map = Dict(1 => 1)))
        LS._init!(solver)
        costs = LS._vars_costs(solver.state)
        excluded = LS.tabu_list(solver.strategies)
        rng = Random.MersenneTwister(seed)
        for i in 1:n
            costs[i] = rand(rng, [-Inf, 0.0, 1.0, 2.0, NaN])
        end
        costs[n] = 2.0
        for i in 1:n
            (seed % 3 == 0 || rand(rng, Bool)) && Dictionaries.set!(excluded, i, 2)
        end
        Dictionaries.set!(excluded, n + 7, 2)
        Dictionaries.set!(excluded, -1, 2)
        solver.state.neighborhood.variable_generation =
            seed % 2 == 0 ? typemax(UInt32) : UInt32(17)
        Random.seed!(seed)
        expected = LS._find_rand_argmax!(Int[], costs, excluded;
            fallback_on_all_excluded = true)
        expected_rng = rand(UInt64)
        Random.seed!(seed)
        @test LS._worst_target(solver.state, solver.strategies) == expected
        @test rand(UInt64) == expected_rng
        @test Set(LS._neighbours(LS._search_context(solver), 1, 1)) == Set(2:n)
    end
end
end
