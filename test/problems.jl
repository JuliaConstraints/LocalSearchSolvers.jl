models = [
    sudoku(2),
]

for m in models
    @info describe(m)
    s = Solver(m, Settings(:verbose => true, :iteration => Inf))
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
    solution(s)

    # TODO: temp patch for coverage, make it nice
    for x in keys(LocalSearchSolvers._tabu(s))
        LocalSearchSolvers._tabu(s, x)
    end
    LocalSearchSolvers._tabu!(s, Dictionary{Int,Int}())
    LocalSearchSolvers._values!(s, Dictionary{Int,Number}())
end

s = Solver(sudoku(3), Settings(:verbose => false))
solve!(s)
solution(s)

s = Solver(golomb(5), Settings(:verbose => false, :iteration => 1000))
solve!(s)

@info "Results golomb!"
@info "Values: $(s.state.values)"
@info "Sol (val): $(s.state.best_solution_value)"
@info "Sol (vals): $(!isnothing(s.state.best_solution_value) ? s.state.best_solution : nothing)"

graph = zeros(5, 5)
graph[1,2] = 1.0
graph[1,3] = 2.0
graph[1,4] = 3.0
graph[2,5] = 1.0
graph[3,5] = 2.0
graph[4,5] = 3.0
s = Solver(mincut(graph, source=1, sink=5), Settings(:verbose => false))
solve!(s)
@info "Results mincut!"
@info "Values: $(s.state.values)"
@info "Sol (val): $(s.state.best_solution_value)"
@info "Sol (vals): $(!isnothing(s.state.best_solution_value) ? s.state.best_solution : nothing)"

s = Solver(mincut(graph, source=1, sink=5, interdiction=1), Settings(:verbose => false))
solve!(s)
@info "Results 1-mincut!"
@info "Values: $(s.state.values)"
@info "Sol (val): $(s.state.best_solution_value)"
@info "Sol (vals): $(!isnothing(s.state.best_solution_value) ? s.state.best_solution : nothing)"

s = Solver(mincut(graph, source=1, sink=5, interdiction=2), Settings(:verbose => false))
solve!(s)
@info "Results 2-mincut!"
@info "Values: $(s.state.values)"
@info "Sol (val): $(s.state.best_solution_value)"
@info "Sol (vals): $(!isnothing(s.state.best_solution_value) ? s.state.best_solution : nothing)"
