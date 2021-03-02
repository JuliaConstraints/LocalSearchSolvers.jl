using JuMP

@testset "JuMP: constraints" begin
    m = JuMP.Model(CBLS.Optimizer)

    err = _ -> 1.0
    concept = _ -> true

    @variable(m, X[1:10], DiscreteSet(1:4))

    @constraint(m, X in Error(err))
    @constraint(m, X in Predicate(concept))

    @constraint(m, X in AllDifferent())
    @constraint(m, X in AllEqual())
    @constraint(m, X in AllEqualParam(2))
    @constraint(m, X in AlwaysTrue())
    @constraint(m, X[1:4] in DistDifferent())
    @constraint(m, X[1:2] in Eq())
    @constraint(m, X in Ordered())
end

@testset "JuMP: sudoku 9x9" begin
    m, X = CBLS.sudoku(3)
    JuMP.optimize!(m)
    solution_ = value.(X)
    display(solution_, Val(:sudoku))
end

@testset "JuMP: golomb(5)" begin
    m, X = CBLS.golomb(5)
    JuMP.optimize!(m)
    @info solution_ = value.(X)
end

@testset "JuMP: magic_square(3)" begin
    m, X = CBLS.magic_square(3)
    JuMP.optimize!(m)
    @info solution_ = value.(X)
end
