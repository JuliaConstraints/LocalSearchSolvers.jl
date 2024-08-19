@testset "Code linting (JET.jl)" begin
    JET.test_package(LocalSearchSolvers; target_defined_modules = true)
end
