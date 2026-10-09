module ShortFloatInvariantRefreshTests
using Test, LocalSearchSolvers, Constraints, Random
const LS = LocalSearchSolvers

function check_refresh(coefficients::Vector{T},values::Vector{T};operator=<=,target=7) where T
    reference = Constraints.SumInvariant(copy(coefficients),zero(T),operator,target)
    owned = deepcopy(reference)
    coefficient_bits = bitstring.(coefficients)
    value_bits = bitstring.(values)
    expected = Constraints.rebuild_invariant!(reference,values)
    actual = LS._rebuild_owned_invariant!(owned,values)
    @test bitstring(owned.total) == bitstring(reference.total) && isequal(actual,expected) &&
        bitstring.(owned.coefficients) == coefficient_bits && bitstring.(values) == value_bits
end

@testset "Short float refresh retains exact exceptional and random bits" begin
    rng = MersenneTwister(931)
    for (T,U) in ((Float32,UInt32),(Float64,UInt64))
        patterns = T[-0.0,0.0,-1.0,1.0,-Inf,Inf,floatmin(T),floatmax(T)]
        append!(patterns,[reinterpret(T,U(1)),reinterpret(T,typemax(U)),
            reinterpret(T,reinterpret(U,T(NaN))|U(1)),
            reinterpret(T,reinterpret(U,T(NaN))|U(7))])
        for a in patterns,b in patterns,c in patterns,d in patterns
            check_refresh(T[a,b],T[c,d])
        end
        for count in (1,2),sample in 1:16384
            check_refresh(collect(reinterpret(T,rand(rng,U,count))),
                collect(reinterpret(T,rand(rng,U,count))))
        end
        for count in (0,1,2),sample in 1:64,operator in (==,!=,<,<=,>,>=),
                target in (7,Float32(-0.0),Float64(7))
            check_refresh(randn(rng,T,count),randn(rng,T,count);operator,target)
        end
    end
end

@testset "Longer and unsupported float shapes retain the reference rebuild" begin
    rng = MersenneTwister(932)
    for T in (Float16,Float32,Float64),count in (0,1,2,3,8,15,16,17,32,128,1024,1025),sample in 1:16
        check_refresh(randn(rng,T,count),randn(rng,T,count))
    end
    for T in (Float32,Float64),target in (UInt(7),Int32(7),Float16(7))
        check_refresh(T[2,-1],T[7,4];target)
    end
    for T in (Float32,Float64),coefficients in (T[],T[1],T[1,2],T[1,2,3]),
            values in (T[],T[1],T[1,2],T[1,2,3])
        length(coefficients)==length(values) && continue
        outcome(f,invariant) = try
            f(invariant,values)
        catch error
            (typeof(error),sprint(showerror,error))
        end
        original = Constraints.SumInvariant(coefficients,T(5),<=,7)
        owned = deepcopy(original)
        @test outcome(LS._rebuild_owned_invariant!,owned) ==
            outcome(Constraints.rebuild_invariant!,original)
        @test owned.total == original.total == T(5)
    end
end

struct ProbeOperator <: Function
    rebuilds::Base.RefValue{Int}
    comparisons::Base.RefValue{Int}
end
function (operator::ProbeOperator)(total,target)
    operator.comparisons[] += 1
    total <= target
end
function Constraints.rebuild_invariant!(
        invariant::Constraints.SumInvariant{Vector{T},T,ProbeOperator,Int},values) where T
    invariant.operator.rebuilds[] += 1
    invoke(Constraints.rebuild_invariant!,Tuple{Constraints.SumInvariant,Any},invariant,values)
end
@testset "Custom float operators retain their rebuild extension" begin
    for T in (Float32,Float64)
        operator = ProbeOperator(Ref(0),Ref(0))
        invariant = Constraints.SumInvariant(T[2,-1],zero(T),operator,7)
        @test LS._rebuild_owned_invariant!(invariant,T[7,4]) == 1.0
        @test invariant.total == T(10)
        @test operator.rebuilds[] == 1 && operator.comparisons[] == 1
    end
end

@testset "Public weighted float refresh matches independent concept truth" begin
    for T in (Float32,Float64),operator in (==,!=,<,<=,>,>=)
        model = LS.model()
        LS.variable!(model,LS.domain(T(-3):T(1):T(3)))
        evaluator = Constraints.bind_error(Constraints.make_error(:sum);
            pair_vars=T[2,-1],op=operator,val=7)
        LS.constraint!(model,evaluator,[1,1])
        solver = LS.solver(model;options=LS.Options(dynamic=false,iteration=1,
            print_level=:silent,log_mode=:silent,log_to_file=false,progress_mode=:none,
            process_threads_map=Dict(1=>1)))
        Random.seed!(41)
        LS._init!(solver)
        for value in T[-0.0,0.0,1.5,floatmin(T),floatmax(T),Inf,-Inf,NaN]
            LS._value!(solver,1,value)
            LS._compute_costs!(solver.model,solver.state,())
            @test LS.get_error(solver) == evaluator(T[value,value])
            @test isequal(first(LS.get_values(solver)),value)
        end
    end
end
end
