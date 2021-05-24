@testset "Raw solver: internals" begin
    models = [
        sudoku(2; modeler=:raw),
    ]

    for m in models
        @info describe(m)
        s = solver(m; options=Options(print_level=:verbose, time_limit = Inf, iteration=Inf, info_path="info.json"))
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
        for x in keys(LocalSearchSolvers.tabu_list(s))
            LocalSearchSolvers.tabu_value(s, x)
        end
        LocalSearchSolvers._values!(s, Dictionary{Int,Int}())

        # display(solution(s))
        @info time_info(s)
        # rm("info.json")
    end
end

# @testset "Raw solver: sudoku" begin
#     sudoku_instance = collect(Iterators.flatten([
#         9  3  0  0  0  0  0  4  0
#         0  0  0  0  4  2  0  9  0
#         8  0  0  1  9  6  7  0  0
#         0  0  0  4  7  0  0  0  0
#         0  2  0  0  0  0  0  6  0
#         0  0  0  0  2  3  0  0  0
#         0  0  8  5  3  1  0  0  2
#         0  9  0  2  8  0  0  0  0
#         0  7  0  0  0  0  0  5  3
#     ]))

#     s = solver(sudoku(3; start = sudoku_instance, modeler = :raw); options = Options(print_level = :minimal, iteration = 100000))
#     display(Dictionary(1:length(sudoku_instance), sudoku_instance))
#     solve!(s)
#     display(solution(s))
# end

# @testset "Raw solver: golomb" begin
#     s = solver(golomb(5, modeler = :raw); options = Options(print_level = :minimal, iteration = 1000))
#     solve!(s)

#     @info "Results golomb!"
#     @info "Values: $(get_values(s))"
#     @info "Sol (val): $(best_value(s))"
#     @info "Sol (vals): $(!isnothing(best_value(s)) ? best_values(s) : nothing)"
# end

# @testset "Raw solver: mincut" begin
#     graph = zeros(5, 5)
#     graph[1,2] = 1.0
#     graph[1,3] = 2.0
#     graph[1,4] = 3.0
#     graph[2,5] = 1.0
#     graph[3,5] = 2.0
#     graph[4,5] = 3.0
#     s = solver(mincut(graph, source=1, sink=5), options =  Options(print_level = :minimal))
#     solve!(s)
#     @info "Results mincut!"
#     @info "Values: $(get_values(s))"
#     @info "Sol (val): $(best_value(s))"
#     @info "Sol (vals): $(!isnothing(best_value(s)) ? best_values(s) : nothing)"

#     s = solver(mincut(graph, source=1, sink=5, interdiction=1), options =  Options(print_level = :minimal))
#     solve!(s)
#     @info "Results 1-mincut!"
#     @info "Values: $(get_values(s))"
#     @info "Sol (val): $(best_value(s))"
#     @info "Sol (vals): $(!isnothing(best_value(s)) ? best_values(s) : nothing)"

#     s = solver(mincut(graph, source=1, sink=5, interdiction=2), options =  Options(print_level = :minimal))
#     solve!(s)
#     @info "Results 2-mincut!"
#     @info "Values: $(get_values(s))"
#     @info "Sol (val): $(best_value(s))"
#     @info "Sol (vals): $(!isnothing(best_value(s)) ? best_values(s) : nothing)"
# end
