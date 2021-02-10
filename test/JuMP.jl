using JuMP

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
