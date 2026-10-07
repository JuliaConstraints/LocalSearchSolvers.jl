@testset "Aqua.jl" begin
    import Aqua
    import LocalSearchSolvers

    Aqua.test_all(
        LocalSearchSolvers;
        ambiguities = (broken = false,),
        deps_compat = false,
        piracies = (broken = false,),
        unbound_args = (broken = false)
    )

    @testset "Piracies: LocalSearchSolvers" begin
        Aqua.test_piracies(LocalSearchSolvers;)
    end

    @testset "Dependencies compatibility (no extras)" begin
        Aqua.test_deps_compat(
            LocalSearchSolvers;
            check_extras = false            # ignore = [:Random]
        )
    end

end
