module ProposalStrategyTests
using Test, Random
import LocalSearchSolvers as LS
import Constraints

function fixture(n=4; threads=1, iterations=256, incremental=false,
        acceptance=LS.GreedyPlateauAcceptance(), selector=LS.RemainingWorstSelector(),
        tabu=LS.EventTabu(2), restart=LS.ExhaustionRestart(reset_fraction=0.5, full_every=4),
        neighborhood=LS.AssignmentNeighborhood(), depths=LS.DepthSchedule(0),
        error=(x;X)->max(0,n÷2-sum(x)), objective=x->sum(i*x[i] for i in eachindex(x)))
    m=LS.model(); foreach(_->LS.variable!(m,LS.domain(0:1)),1:n)
    f=incremental ? Constraints.bind_error(Constraints.penalty_f(:sum,:value);op = >=,val=n÷2) : error
    LS.constraint!(m,f,1:n); LS.objective!(m,objective)
    strats=LS.MetaStrategy(m;variable_selection=selector,neighborhood,depths,acceptance,tabu,restart)
    options=LS.Options(iteration=(false,iterations),time_limit=(false,60.0),
        process_threads_map=Dict(1=>threads),print_level=:silent,log_mode=:silent,
        log_to_file=false,progress_mode=:none,use_progress_meter=false)
    LS.solver(m;options,strategies=strats)
end
function set_values!(s, x)
    for (i,v) in enumerate(x); LS._value!(s,i,v); end
    LS._compute!(s)
    LS._initialize_proposals!(s,s.strategies)
end
snapshot(s)=(collect(LS.get_values(s)),LS.get_error(s),LS.get_value(s),
    collect(LS.best_values(s)),LS.best_value(s),copy(LS._cons_costs(s)))

@testset "Explicit proposal strategy contracts" begin
    @testset "Acceptance and tabu clocks" begin
        yes=LS.GreedyPlateauAcceptance(reject_plateau_percent=0)
        no=LS.GreedyPlateauAcceptance(reject_plateau_percent=100)
        @test LS.decide_move(no,(0.0,9.0),(1.0,0.0))===:accepted
        @test LS.decide_move(yes,(2.0,0.0),(1.0,9.0))===:rejected
        @test LS.decide_move(no,(1.0,2.0),(1.0,3.0))===:accepted
        @test LS.decide_move(no,(1.0,3.0),(1.0,3.0))===:plateau_rejected
        @test LS.decide_move(yes,(1.0,3.0),(1.0,3.0))===:accepted
        @test LS.decide_move(yes,(NaN,3.0),(1.0,3.0))===:rejected
        @test_throws ArgumentError LS.GreedyPlateauAcceptance(reject_plateau_percent=-1)
        @test_throws ArgumentError LS.EventTabu(2;clock=:wall)
        @test_throws ArgumentError LS.EventTabu(-1)
        for clock in (:accepted,:proposal)
            ts=LS.EventTabu(2;clock)
            LS.insert_tabu!(ts,1,:tabu)
            LS._advance_proposal_tabu!(ts,:rejected)
            @test LS.tabu_value(ts,1)==(clock===:accepted ? 2 : 1)
            LS._advance_proposal_tabu!(ts,:accepted)
            @test LS.length_tabu(ts)==(clock===:accepted ? 1 : 0)
            LS._advance_proposal_tabu!(ts,:accepted)
            @test LS.length_tabu(ts)==0
            LS.insert_tabu!(ts,1,:pick)
            @test LS.length_tabu(ts)==0
        end
    end
    @testset "Refusal, acceptance, remaining variables and reset" begin
        s=fixture(4;error=(x;X)->sum(x),objective=x->0.0)
        LS._init!(s);set_values!(s,zeros(Int,4));before=snapshot(s)
        for remaining in 3:-1:0
            LS._step!(s)
            @test snapshot(s)==before
            @test length(s.strategies.variable_selection.pending)==remaining
        end
        @test LS.length_tabu(s.strategies)==1
        LS._step!(s)
        @test s.strategies.restart.resets==1
        @test s.strategies.variable_selection.refresh
        @test LS.length_tabu(s.strategies)==0
        @test LS.get_error(s)==sum(LS.get_values(s))
        for pct in (0,100)
            s=fixture(4;error=(x;X)->0.0,objective=x->0.0,
                acceptance=LS.GreedyPlateauAcceptance(reject_plateau_percent=pct))
            LS._init!(s);set_values!(s,zeros(Int,4));before=snapshot(s)
            LS._step!(s)
            @test (sum(LS.get_values(s))==1)==(pct==0)
            @test (snapshot(s)==before)==(pct==100)
            @test LS.length_tabu(s.strategies)==(pct==100 ? 1 : 0)
        end
        rs=LS.ExhaustionRestart(reset_fraction=0.25,full_every=3)
        for k in 1:6
            rs.resets=k
            @test LS.restart_fraction(rs)==(k%3==0 ? 1.0 : 0.25)
        end
    end
    @testset "Oracle and incremental state over accepted and rejected steps" begin
        for incremental in (false,true), clock in (:accepted,:proposal), guide in (false,true)
            Random.seed!(73)
            s=fixture(8;incremental,tabu=LS.EventTabu(2;clock),
                acceptance=LS.GreedyPlateauAcceptance(guide_infeasible=guide))
            LS._init!(s)
            for k in 1:128
                LS._step!(s)
                x=collect(LS.get_values(s));best=collect(LS.best_values(s))
                @test LS.get_error(s)==max(0,4-sum(x))
                @test !LS.has_solution(s) || (sum(best)>=4 && LS.best_value(s)==sum(i*best[i] for i in 1:8))
                for id in 1:8
                    candidate=copy(x);candidate[id]=1-candidate[id]
                    @test LS._candidate_cost(s,LS.AssignMove(id,candidate[id]))==max(0,4-sum(candidate))
                end
            end
        end
    end
    @testset "Composable neighborhood, selector and tabu" begin
        for selector in (LS.WorstVariableSelector(),LS.RemainingWorstSelector()),
                tabu in (LS.NoTabu(),LS.tabu(2,1),LS.EventTabu(2)),
                neighborhood in (LS.AssignmentNeighborhood(),LS.AssignSwapNeighborhood())
            depths=neighborhood isa LS.AssignmentNeighborhood ? LS.DepthSchedule(0) : LS.DepthSchedule(0,1)
            s=fixture(4;selector=deepcopy(selector),tabu=deepcopy(tabu),neighborhood,depths)
            LS.solve!(s)
            @test LS.iterations(s)==256
            @test LS.has_solution(s)
            @test sum(LS.best_values(s))>=2
        end
    end
    @testset "Thread ownership and solve reinitialization" begin
        t=min(8,Threads.nthreads())
        Random.seed!(5);s=fixture(8;threads=t,iterations=512,incremental=true)
        LS.solve!(s); units=[s;s.subs]
        @test length(units)==t
        @test all(u->LS.iterations(u)==512,units)
        for i in eachindex(units),j in 1:i-1
            @test units[i].strategies.variable_selection.pending !== units[j].strategies.variable_selection.pending
            @test LS.tabu_list(units[i].strategies) !== LS.tabu_list(units[j].strategies)
            @test units[i].strategies.acceptance !== units[j].strategies.acceptance
            @test units[i].strategies.restart !== units[j].strategies.restart
        end
        s.strategies.restart.resets=999
        LS._init!(s)
        @test s.strategies.restart.resets==0
        @test isempty(s.strategies.variable_selection.pending)
        @test s.strategies.acceptance.current_objective==(LS.get_error(s)==0 ? LS.get_value(s) : Inf)
        wrong=fixture(4;acceptance=LS.BestImprovingAcceptance())
        @test_throws ArgumentError LS._init!(wrong)
        wrong=fixture(4;depths=LS.DepthSchedule(0,1))
        @test_throws ArgumentError LS._init!(wrong)
    end
    @testset "Progress fields preserve tracking and first-solution timestamps" begin
        s=fixture(4);LS._init!(s)
        for Tracker in (LS.ProgressTracker,LS.ProgressMeterTracker),enabled in (false,true)
            reference=Tracker(mode=LS.NONE,total_iterations=10)
            reference.enabled=enabled
            tracker=deepcopy(reference)
            for (i,x) in enumerate(([0,0,0,0],[1,1,1,1],[1,1,0,0]))
                set_values!(s,x)
                LS.update_progress!(reference;iteration=i,error=LS.get_error(s),
                    objective=LS._optimizing(s.state) ? LS.get_value(s.state) : nothing)
                LS._update_iteration_progress!(tracker,s.state,i)
                for field in (:current_iteration,:current_error,:initial_error,:best_objective,
                        :has_valid_solution,:valid_solution_time,:valid_solution_iteration)
                    @test getproperty(tracker,field)==getproperty(reference,field)
                end
                if Tracker===LS.ProgressTracker
                    @test tracker.last_update_time==reference.last_update_time
                end
            end
            before=time()
            timestamp=LS.update_progress!(tracker;has_valid_solution=true)
            @test timestamp isa Float64 && before<=timestamp<=time()
            if enabled || Tracker===LS.ProgressTracker
                @test tracker.has_valid_solution
                @test tracker.valid_solution_iteration==3
                @test tracker.valid_solution_time==timestamp-tracker.start_time
                first=tracker.valid_solution_time
                LS._update_iteration_progress!(tracker,s.state,4)
                LS.update_progress!(tracker;has_valid_solution=true)
                @test tracker.valid_solution_time==first
            else
                @test !tracker.has_valid_solution
            end
        end
    end
end
end
