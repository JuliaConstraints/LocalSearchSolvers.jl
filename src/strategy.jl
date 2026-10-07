"Explicit context of one prepared iteration; phases must publish found before completion."
mutable struct PreparedStepState{S}
    solver::S
    found::Bool
end
export PreparedStepState

"""Concrete, factorized CBLS strategy composition executed by one search unit."""
struct MetaStrategy{VS <: AbstractVariableSelector,
    NG <: AbstractNeighborhoodGenerator,
    DS <: DepthSchedule,
    AS <: AbstractAcceptanceStrategy,
    RS <: RestartStrategy,
    TS <: TabuStrategy}
    variable_selection::VS
    neighborhood::NG
    depths::DS
    acceptance::AS
    restart::RS
    tabu::TS
    description::NamedTuple
end
MetaStrategy(v,n,d,a,r,t)=MetaStrategy(v,n,d,a,r,t,(;))
function Base.deepcopy_internal(strategy::MetaStrategy,dict::IdDict)
    haskey(dict,strategy) && return dict[strategy]
    copy=MetaStrategy((Base.deepcopy_internal(getfield(strategy,n),dict) for n in fieldnames(typeof(strategy)))...)
    dict[strategy]=copy
    copy
end

abstract type AbstractCostUpdate end
struct RuntimeCostUpdate <: AbstractCostUpdate end
struct FullCostUpdate <: AbstractCostUpdate end
struct IncrementalCostUpdate <: AbstractCostUpdate end
@inline _update_move_costs!(::FullCostUpdate,model,state,affected)=_compute_costs!(model,state,affected)
@inline _update_move_costs!(::IncrementalCostUpdate,model,state,affected)=_compute_committed_costs!(model,state,affected)
@inline function _update_move_costs!(::RuntimeCostUpdate,model,state,affected)
    if _has_incremental(state)
        _compute_committed_costs!(model,state,affected)
    else
        _compute_costs!(model,state,affected)
    end
end

@testitem "Configured strategies are cloned into threaded search units" default_imports=false begin
    import ConstraintDomains: domain
    import LocalSearchSolvers as LS
    import Test: @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:3)), 1:3)
    LS.constraint!(model, (values; X) -> 1.0, 1:3)
    tabu_strategy = LS.tabu(3)
    strategy = LS.MetaStrategy(
        LS.WorstVariableSelector(),
        LS.AssignSwapNeighborhood(),
        LS.DepthSchedule(0),
        LS.BestImprovingAcceptance(),
        LS.restart(tabu_strategy, Val(:random); rp = 0.0),
        tabu_strategy
    )
    thread_count = min(2, Threads.nthreads())
    solver = LS.solver(model;
        strategies = strategy,
        options = LS.Options(
            print_level = :silent,
            iteration = 1,
            process_threads_map = Dict(1 => thread_count)
        ))
    LS._init!(solver)
    @test length(solver.subs) == thread_count - 1
    if thread_count > 1
        @test only(solver.subs).strategies.tabu isa LS.KeenTabu
        @test LS.tabu_list(only(solver.subs).strategies.tabu) !==
              LS.tabu_list(solver.strategies.tabu)
    end
end

@testitem "Typed composition accepts mixed symbolic and numeric domains" default_imports=false begin
    import ConstraintDomains
    import Constraints
    import LocalSearchSolvers as LS
    import Test: @test

    model = LS.model()
    # `domain` keeps this package's isolated tests compatible with the released
    # ConstraintDomains boundary; ArbitraryDomain itself is tested in that package.
    LS.variable!(model, ConstraintDomains.domain((:red, :green)))
    LS.variable!(model, ConstraintDomains.domain((:red, :green)))
    LS.variable!(model, ConstraintDomains.domain(1:2))
    LS.constraint!(model, Constraints.make_error(:all_different), 1:3)
    solver = LS.solver(model;
        options = LS.Options(
            print_level = :silent,
            iteration = 1,
            process_threads_map = Dict(1 => 1)
        ))
    LS._init!(solver)
    LS._value!(solver, 1, :red)
    LS._value!(solver, 2, :red)
    LS._value!(solver, 3, 1)
    LS._compute!(solver)

    move = LS.AssignMove(2, :green)
    @test LS._candidate_cost(solver, move) == 0.0
    affected = LS._commit!(solver, move)
    LS._compute_committed!(solver; cons_lst = affected)
    @test LS.get_error(solver) == 0.0
end

function MetaStrategy(model;
        variable_selection = WorstVariableSelector(),
        neighborhood = AssignSwapNeighborhood(),
        depths = compatibility_depths(),
        acceptance = BestImprovingAcceptance(),
        tenure = min(length_vars(model) ÷ 2, 10),
        tabu = tabu(tenure, tenure ÷ 2),
        restart = restart(tabu, Val(:universal)),
        logger = nothing
)
    if !isnothing(logger)
        @ls_info logger "MetaStrategy: $variable_selection, $neighborhood, $depths, $acceptance, $restart, $tabu, $tenure"
    end
    return MetaStrategy(
        variable_selection, neighborhood, depths, acceptance, restart, tabu)
end

# Preserve the previous positional constructor as a compatibility composition.
function MetaStrategy(restart::RS, tabu::TS) where {
        RS <: RestartStrategy, TS <: TabuStrategy}
    MetaStrategy(WorstVariableSelector(), AssignSwapNeighborhood(), compatibility_depths(),
        BestImprovingAcceptance(), restart, tabu)
end

# forwards from RestartStrategy
@forward MetaStrategy.restart check_restart!

# forwards from TabuStrategy
@forward MetaStrategy.tabu decrease_tabu!, delete_tabu!, decay_tabu!
@forward MetaStrategy.tabu length_tabu, insert_tabu!, empty_tabu!, tabu_list

@testitem "Typed strategy composition preserves the compatibility search" default_imports=false begin
    import ConstraintDomains: domain
    import Constraints
    import LocalSearchSolvers as LS
    import Test: @inferred, @test, @test_throws

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:4)), 1:4)
    LS.constraint!(model, Constraints.make_error(:all_different), 1:4)
    strategy = LS.MetaStrategy(model)
    @test strategy.variable_selection isa LS.WorstVariableSelector
    @test strategy.neighborhood isa LS.AssignSwapNeighborhood
    @test collect(strategy.depths) == [0, 1]
    @test strategy.acceptance isa LS.BestImprovingAcceptance
    @test strategy.restart isa LS.RestartSequence
    @test LS.restart_fraction(strategy.restart) == 1.0
    @test LS.restart_source(strategy.restart) === :current
    @test LS.tenure(strategy.tabu, :tabu) == 2
    @test_throws ArgumentError LS.DepthSchedule()
    @test_throws ArgumentError LS.DepthSchedule(0, -1)

    solver = LS.solver(model;
        strategies = strategy,
        options = LS.Options(
            print_level = :silent,
            iteration = 1,
            process_threads_map = Dict(1 => 1)
        ))
    LS._init!(solver)
    target = @inferred LS.select_target(strategy.variable_selection, solver)
    @test target in 1:4
    @test @inferred(LS.candidate_relation(
        strategy.acceptance, (0.0, Inf), (1.0, Inf))) == 1
end
