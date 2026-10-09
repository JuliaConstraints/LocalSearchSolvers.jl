module IntegerInvariantRefreshTests
using Test, LocalSearchSolvers, Constraints, Random
const LS = LocalSearchSolvers
const refresh! = isdefined(LS, :_rebuild_owned_invariant!) ?
    getfield(LS, :_rebuild_owned_invariant!) : Constraints.rebuild_invariant!

@testset "Integer sum refresh preserves exact machine arithmetic" begin
    rng = MersenneTwister(927)
    modulus = big(2)^Sys.WORD_SIZE
    for count in (0,1,2,3,8,16,32,128,256), sample in 1:32,
            operator in (==, !=, <, <=, >, >=)
        coefficients = rand(rng, Int, count)
        values = rand(rng, Int, count)
        original_values = copy(values)
        target = rand(rng, Int)
        original = Constraints.SumInvariant(copy(coefficients), zero(Int), operator, target)
        owned = deepcopy(original)
        expected_cost = Constraints.rebuild_invariant!(original, values)
        actual_cost = refresh!(owned, values)
        mathematical_total = sum((big(c)*big(v) for (c,v) in zip(coefficients,values)); init=big(0))
        expected_total = reinterpret(Int, UInt(mod(mathematical_total,modulus)))
        @test owned.total == original.total == expected_total
        @test actual_cost == expected_cost == Float64(!operator(expected_total,target))
        @test owned.coefficients == coefficients && values == original_values
    end
    original = Constraints.SumInvariant([1,2], 7, <=, 3)
    for values in (Int[], [1], [1,2,3])
        outcome(f, invariant) = try
            f(invariant, values)
        catch error
            (typeof(error), sprint(showerror,error))
        end
        owned = deepcopy(original)
        @test outcome(refresh!,owned) == outcome(Constraints.rebuild_invariant!,original)
        @test owned.total == original.total == 7
    end
end

@testset "Other numeric sum types keep exact reference results" begin
    rng = MersenneTwister(928)
    for T in (Int32, Float32, Float64), count in (0,1,2,3,8,32), sample in 1:16
        coefficients = rand(rng,T,count)
        values = rand(rng,T,count)
        original = Constraints.SumInvariant(copy(coefficients),zero(T),<=,T(1))
        owned = deepcopy(original)
        @test isequal(refresh!(owned,values),Constraints.rebuild_invariant!(original,values))
        @test bitstring(owned.total) == bitstring(original.total)
    end
    for target in (Float64(-0.0), UInt(7), Int32(7))
        original = Constraints.SumInvariant([1,-2,3], 0, <=, target)
        owned = deepcopy(original)
        @test refresh!(owned,[7,4,2]) == Constraints.rebuild_invariant!(original,[7,4,2])
        @test owned.total == original.total
    end
end

struct ProbeOperator <: Function
    rebuilds::Base.RefValue{Int}
    values::Base.RefValue{Int}
end
function (operator::ProbeOperator)(total,target)
    operator.values[] += 1
    total <= target
end
function Constraints.rebuild_invariant!(
        invariant::Constraints.SumInvariant{Vector{Int},Int,ProbeOperator,Int},values)
    invariant.operator.rebuilds[] += 1
    invoke(Constraints.rebuild_invariant!,Tuple{Constraints.SumInvariant,Any},invariant,values)
end
@testset "Custom invariant operators retain their rebuild extension" begin
    operator = ProbeOperator(Ref(0),Ref(0))
    invariant = Constraints.SumInvariant([2,-1,3],0,operator,7)
    @test refresh!(invariant,[1,2,3]) == 1.0
    @test invariant.total == 9
    @test operator.rebuilds[] == 1 && operator.values[] == 1
end

@testset "Solver refresh agrees with full weighted-sum truth" begin
    for operator in (==, !=, <, <=, >, >=)
        model = LS.model()
        foreach(_ -> LS.variable!(model,LS.domain(-3:3)),1:3)
        evaluator = Constraints.bind_error(Constraints.make_error(:sum);
            pair_vars=[2,-1,3,4], op=operator, val=7)
        LS.constraint!(model,evaluator,[1,2,3,1])
        solver = LS.solver(model;options=LS.Options(dynamic=false,iteration=1,
            print_level=:silent,log_mode=:silent,log_to_file=false,progress_mode=:none,
            process_threads_map=Dict(1=>1)))
        Random.seed!(41)
        LS._init!(solver)
        for assignment in ((1,2,3),(-3,0,3),(typemax(Int),typemin(Int),-1),(0,0,0))
            for (id,value) in enumerate(assignment)
                LS._value!(solver,id,value)
            end
            LS._compute_costs!(solver.model,solver.state,())
            expected_total = 6*assignment[1]-assignment[2]+3*assignment[3]
            @test LS.get_error(solver) == Float64(!operator(expected_total,7))
            @test LS._invariant(solver.state,1).total == expected_total
            @test collect(LS.get_values(solver)) == collect(assignment)
        end
    end
end
end
