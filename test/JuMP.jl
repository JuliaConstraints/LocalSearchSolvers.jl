using JuMP

@testset "JuMP: constraints" begin
    m = Model(CBLS.Optimizer)

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
    m, X = sudoku(3)
    optimize!(m)
    solution_ = value.(X)
    display(solution_, Val(:sudoku))
end

@testset "JuMP: golomb(5)" begin
    m, X = golomb(5)
    optimize!(m)
    @info "JuMP: golomb(5)" value.(X)
end

@testset "JuMP: magic_square(3)" begin
    m, X = magic_square(3)
    optimize!(m)
    @info "JuMP: magic_square(3)" value.(X)
end

@testset "JuMP: n_queens(5)" begin
    m, X = n_queens(5)
    optimize!(m)
    @info "JuMP: n_queens(5)" value.(X)
end

@testset "JuMP: basic opt" begin
    model = Model(CBLS.Optimizer)
    MOI.set(model, CBLS.PrintLevel(), :verbose) # NOTE - work
    # set_optimizer_attribute(model, "CBLS.PrintLevel", :verbose) # FIXME - RawParameter
    set_time_limit_sec(model, 10.0)
    @info time_limit_sec(model)

    @variable(model, x in DiscreteSet(0:20))
    @variable(model, y in DiscreteSet(0:20))

    @constraint(model, [x,y] in Predicate(v -> 6v[1] + 8v[2] >= 100 ))
    @constraint(model, [x,y] in Predicate(v -> 7v[1] + 12v[2] >= 120 ))

    objFunc = v -> 12v[1] + 20v[2]
    @objective(model, Min, ScalarFunction(objFunc))

    optimize!(model)

    @info "JuMP: basic opt" value(x) value(y) (12*value(x)+20*value(y))
end