@testset "Look for Explicit Imports" begin
    @test check_no_implicit_imports(LocalSearchSolvers) === nothing
end