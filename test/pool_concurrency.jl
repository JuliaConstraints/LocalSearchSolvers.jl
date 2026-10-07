module PoolPublicationTests
using Test
import LocalSearchSolvers as LS
function config(score)
    LS.Configuration(true,Float64(score),LS.Dictionary([1],[score]))
end
@testset "Concurrent pool publication exposes complete snapshots" begin
    s=LS.solver();LS._replace_pool!(s,LS.pool(config(1000)))
    ready=Channel{Nothing}(3);go=Channel{Nothing}(1)
    tasks=Task[]
    for worker in 1:3
        push!(tasks,Threads.@spawn begin
            put!(ready,nothing);fetch(go)
            if worker<=2
                for i in 1:100
                    LS._consider_configuration!(s,config(1000-2i-worker))
                    i%5==0 && yield()
                end
                true
            else
                all_consistent=true
                for _ in 1:1000
                    snapshot=LS._pool_snapshot(s)
                    all_consistent &= LS.best_value(snapshot)==only(LS.best_values(snapshot))
                    yield()
                end
                all_consistent
            end
        end)
    end
    for _ in 1:3;take!(ready);end
    put!(go,nothing)
    @test all(fetch, tasks)
    @test LS.best_value(s)==798
    @test collect(LS.best_values(s))==[798]
end
end
