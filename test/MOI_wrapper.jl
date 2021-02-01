using MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

const OPTIMIZER_CONSTRUCTOR = MOI.OptimizerWithAttributes(
    LocalSearchSolvers.Optimizer, MOI.Silent() => true
)
const OPTIMIZER = MOI.instantiate(OPTIMIZER_CONSTRUCTOR)

@testset "LocalSearchSolvers" begin
    @test MOI.get(OPTIMIZER, MOI.SolverName()) == "LocalSearchSolvers"
end

@testset "supports_default_copy_to" begin
    @test MOIU.supports_default_copy_to(OPTIMIZER, false)
    # Use `@test !...` if names are not supported
    @test !MOIU.supports_default_copy_to(OPTIMIZER, true)
end

const BRIDGED = MOI.instantiate(
    OPTIMIZER_CONSTRUCTOR, with_bridge_type = Float64
)
const CONFIG = MOIT.TestConfig(atol=1e-6, rtol=1e-6)

@testset "Unit" begin
    # Test all the functions included in dictionary `MOI.Test.unittests`,
    # except functions "number_threads" and "solve_qcp_edge_cases."
    MOIT.unittest(
        BRIDGED,
        CONFIG,
        ["number_threads", "solve_qcp_edge_cases"]
    )
end

# @testset "Modification" begin
#     MOIT.modificationtest(BRIDGED, CONFIG)
# end

# @testset "Continuous Linear" begin
#     MOIT.contlineartest(BRIDGED, CONFIG)
# end

# @testset "Continuous Conic" begin
#     MOIT.contlineartest(BRIDGED, CONFIG)
# end

# @testset "Integer Conic" begin
#     MOIT.intconictest(BRIDGED, CONFIG)
# end
