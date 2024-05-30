@testset "Aqua.jl" begin
    import Aqua
    import LocalSearchSolvers

    # TODO: Fix the broken tests and remove the `broken = true` flag
    Aqua.test_all(
        LocalSearchSolvers;
        ambiguities = (broken = true,),
        deps_compat = false,
        piracies = (broken = false,),
        unbound_args = (broken = false)
    )

    @testset "Ambiguities: LocalSearchSolvers" begin
        # Aqua.test_ambiguities(LocalSearchSolvers;)
    end

    @testset "Piracies: LocalSearchSolvers" begin
        Aqua.test_piracies(LocalSearchSolvers;)
    end

    @testset "Dependencies compatibility (no extras)" begin
        Aqua.test_deps_compat(
            LocalSearchSolvers;
            check_extras = false            # ignore = [:Random]
        )
    end

    @testset "Unbound type parameters" begin
        # Aqua.test_unbound_args(LocalSearchSolvers;)
    end
end
