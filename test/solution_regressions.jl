module SolutionRegressionTests
using Test, Random
include("fix_fixture.jl")
const F=CBLSFixFixture
const LS=F.LS
@testset "Solution scores and immutable pool publication" begin
    @test_throws ArgumentError LS.Options(solutions=0)
    @test_throws ArgumentError LS.set_option!(LS.Options(),:solutions,0)
    for threads in unique([1,min(2,Threads.nthreads())]), kind in (:optimization,:max,:satisfaction), seed in 1:3
        Random.seed!(seed);s=F.build(Dict(1=>threads);kind)
        LS.solve!(s);actual=F.truth(s)
        @test actual.feasible==iszero(actual.error)
        @test actual.score==(actual.feasible ? actual.objective : actual.error)
        @test all(LS.iterations(unit)<=16 for unit in Any[s;s.subs])
    end
    # Objective magnitude may exceed infeasibility by any amount.
    m=LS.model();LS.variable!(m,LS.domain(0:1));LS.constraint!(m,(x;X)->1.0-x[1],[1]);LS.objective!(m,x->10.0)
    s=LS.solver(m;options=F.build(Dict(1=>1)).options);LS._init!(s)
    LS._value!(s,1,0);LS._compute!(s);LS._replace_pool!(s,LS.pool(s.state.configuration))
    LS._step!(s)
    @test LS.has_solution(s) && LS.best_value(s)==10
    @test collect(LS.best_values(s))==[1]
    # Pool admission must not depend on caller ordering, and must own its values.
    s=F.build(Dict(1=>1);solutions=3);LS._init!(s);LS._replace_pool!(s,LS.pool())
    for (value,assignment) in [(3.,[0,0]),(2.,[0,1]),(1.,[0,2]),(4.,[1,0]),(1.,[0,2])]
        config=LS.Configuration(true,value,LS.Dictionary(1:2,assignment))
        LS._consider_configuration!(s,config);config.values[1]=99
    end
    @test LS.get_value.(s.pool.configurations)==[1,2,3]
    @test all(99 ∉ collect(c.values) for c in s.pool.configurations)
    old=LS._pool_snapshot(s)
    LS._consider_configuration!(s,LS.Configuration(false,0.,LS.Dictionary(1:2,[1,1])))
    @test LS._pool_snapshot(s)===old
    LS._consider_configuration!(s,LS.Configuration(true,10.,LS.Dictionary(1:2,[1,2])))
    @test LS._pool_snapshot(s)===old
    Random.seed!(12);s=F.build(Dict(1=>1);kind=:many,solutions=3,budget=64);LS.solve!(s)
    @test length(s.pool.configurations)==3
    @test length(unique(collect(c.values) for c in s.pool.configurations))==3
    s=F.build(Dict(1=>min(2,Threads.nthreads())));LS.solve!(s);count=length(s.subs);LS.solve!(s)
    @test length(s.subs)==count
    @test F.truth(s).score==F.truth(s).objective
    s=F.build(Dict(1=>1);kind=:many);LS.solve!(s)
    @test LS.iterations(s)==0 && LS.status(s)==:solution_limit
    @test empty!(s)===s && !LS.has_solution(s) && LS.iterations(s)==0
end
end
