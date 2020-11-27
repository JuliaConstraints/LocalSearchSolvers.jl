problems = [
    sudoku(2),
]

for p in problems
    println(describe(p))
    s = Solver{Int}(p)
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
    solve!(s, max_iteration = 10, verbose = true)
    
    # TODO: temp patch for coverage, make it nice
    for x in keys(LocalSearchSolvers._tabu(s))
        LocalSearchSolvers._tabu(s, x)
    end
    LocalSearchSolvers._tabu!(s, Dictionary{Int, Int}())
    LocalSearchSolvers._values!(s, Dictionary{Int, typeof(s).parameters[1]}())
end
