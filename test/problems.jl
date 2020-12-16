problems = [
    sudoku(2),
]

for p in problems
    println(describe(p))
    s = Solver(p, Settings(:verbose => true, :iteration => Inf))
    for x in keys(get_variables(s))
        @test get_name(s, x) == "x$x"
        for c in get_cons_from_var(s, x)
            @test x ∈ get_vars_from_cons(s, c)
        end
        @test constriction(s, x) == 3
        @test draw(s, x) ∈ get_domain(s, x)
    end

    for c in keys(get_constraints(s))
        @test length_cons(s, c) == 4
    end

    for x in keys(get_variables(s))
        add_var_to_cons!(s, 3, x)
        delete_var_from_cons!(s, 3, x)
        add_value!(s, x, 5)
        @test length_var(s, x) == 5
        delete_value!(s, x, 5)
        @test length_var(s, x) == 4
    end

    for c in keys(get_constraints(s))
        add_var_to_cons!(s, c, 17)
        @test length_cons(s, c) == 5
        @test 17 ∈ get_constraint(s, c)
        delete_var_from_cons!(s, c, 17)
        @test length_cons(s, c) == 4
    end
    solve!(s)

    # TODO: temp patch for coverage, make it nice
    for x in keys(LocalSearchSolvers._tabu(s))
        LocalSearchSolvers._tabu(s, x)
    end
    LocalSearchSolvers._tabu!(s, Dictionary{Int, Int}())
    LocalSearchSolvers._values!(s, Dictionary{Int, Number}())
end

solve!(Solver(sudoku(3), Settings(:verbose => false)))

# # println(describe(golomb(10)))
s = Solver(golomb(5), Settings(:verbose => false, :iteration => 1000))
solve!(s)

println("\nResults!")
println("Values: $(s.state.values)")
println("Sol (val): $(s.state.best_solution_value)")
println("Sol (vals): $(!isnothing(s.state.best_solution_value) ? s.state.best_solution : nothing)")
