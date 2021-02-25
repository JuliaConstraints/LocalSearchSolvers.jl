using MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

const VOV = MOI.VectorOfVariables
const VI = MOI.VariableIndex

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

# @testset "Unit" begin
#     # Test all the functions included in dictionary `MOI.Test.unittests`,
#     # except functions "number_threads" and "solve_qcp_edge_cases."
#     MOIT.unittest(
#         BRIDGED,
#         CONFIG,
#         ["number_threads", "solve_qcp_edge_cases"]
#     )
# end

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
@testset "MOI: examples" begin
    # m = LocalSearchSolvers.Optimizer()
    # MOI.add_variables(m, 3)
    # MOI.add_constraint(m, VI(1), LS.DiscreteSet([1,2,3]))
    # MOI.add_constraint(m, VI(2), LS.DiscreteSet([1,2,3]))
    # MOI.add_constraint(m, VI(3), LS.DiscreteSet([1,2,3]))

    # MOI.add_constraint(m, VOV([VI(1),VI(2)]), LS.MOIPredicate(allunique))
    # MOI.add_constraint(m, VOV([VI(2),VI(3)]), LS.MOIAllDifferent(2))

    # MOI.set(m, MOI.ObjectiveFunction{LS.ScalarFunction}(), LS.ScalarFunction(sum, VI(1)))

    # MOI.optimize!(m)

    m1 = LocalSearchSolvers.Optimizer()
    MOI.add_variable(m1)
    MOI.add_constraint(m1, VI(1), LS.DiscreteSet([1,2,3]))

    m2 = LocalSearchSolvers.Optimizer()
    MOI.add_constrained_variable(m2, LS.DiscreteSet([1,2,3]))

    opt = CBLS.sudoku(3, modeler = :MOI)
    MOI.optimize!(opt)
    @info solution(opt)
end
