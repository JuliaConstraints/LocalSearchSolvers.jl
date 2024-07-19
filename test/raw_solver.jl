function mincut(graph; source, sink, interdiction = 0)
    m = model(; kind = :cut)
    n = size(graph, 1)

    d = domain(0:n)

    separator = n + 1 # value that separate the two sides of the cut

    # Add variables:
    foreach(_ -> variable!(m, d), 0:n)

    # Extract error function from usual_constraint
    e1 = (x; X) -> error_f(USUAL_CONSTRAINTS[:ordered])(x)
    e2 = (x; X) -> error_f(USUAL_CONSTRAINTS[:all_different])(x)

    # Add constraint
    constraint!(m, e1, [source, separator, sink])
    constraint!(m, e2, 1:(n + 1))

    # Add objective
    objective!(m, (x...) -> o_mincut(graph, x...; interdiction))

    return m
end

function golomb(n, L = n^2)
    m = model(; kind = :golomb)

    # Add variables
    d = domain(0:L)
    foreach(_ -> variable!(m, d), 1:n)

    # Extract error function from usual_constraint
    e1 = (x; X) -> error_f(USUAL_CONSTRAINTS[:all_different])(x)
    e2 = (x; X) -> error_f(USUAL_CONSTRAINTS[:all_equal])(x; val = 0)
    e3 = (x; X) -> error_f(USUAL_CONSTRAINTS[:dist_different])(x)

    # # Add constraints
    constraint!(m, e1, 1:n)
    constraint!(m, e2, 1:1)
    for i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n
        (i, j) < (k, l) || continue
        constraint!(m, e3, [i, j, k, l])
    end

    # Add objective
    objective!(m, o_dist_extrema)

    return m
end

function sudoku(n; start = nothing)
    N = n^2
    d = domain(1:N)

    m = model(; kind = :sudoku)

    # Add variables
    if isnothing(start)
        foreach(_ -> variable!(m, d), 1:(N^2))
    else
        foreach(((x, v),) -> variable!(m, 1 ≤ v ≤ N ? domain(v) : d), pairs(start))
    end

    e = (x; X) -> error_f(USUAL_CONSTRAINTS[:all_different])(x)

    # Add constraints: line, columns; blocks
    foreach(i -> constraint!(m, e, (i * N + 1):((i + 1) * N)), 0:(N - 1))
    foreach(i -> constraint!(m, e, [j * N + i for j in 0:(N - 1)]), 1:N)

    for i in 0:(n - 1)
        for j in 0:(n - 1)
            vars = Vector{Int}()
            for k in 1:n
                for l in 0:(n - 1)
                    push!(vars, (j * n + l) * N + i * n + k)
                end
            end
            constraint!(m, e, vars)
        end
    end

    return m
end

function chemical_equilibrium(A, B, C)
    m = model(; kind = :equilibrium)

    N = length(C)
    M = length(B)

    d = domain(0..maximum(B))
    
    # Add variables, number of moles per compound

    foreach(_ -> variable!(m, d), 1:N)

    # mass_conservation function
    conserve = i -> (x ->
        begin
            δ = abs(sum(A[:, i] .* x) - B[i])
            return δ ≤ 1.e-6 ? 0. : δ
        end
    )
    
    # Add constraints
    for i in 1:M
        constraint!(m, conserve(i), 1:N)
    end

    # computes the total energy freed by the reaction
    free_energy = x -> sum(j -> x[j] * (C[j] + log(x[j] / sum(x))))

    objective!(m, free_energy)

    return m
end

@testset "Raw solver: internals" begin
    models = [
        sudoku(2)
    ]

    for m in models
        # @info describe(m)
        options = Options(
            print_level = :verbose,
            time_limit = Inf,
            iteration = Inf,
            info_path = "info.json",
            process_threads_map = Dict{Int, Int}(
                [2 => 2, 3 => 1]
            ))
        s = solver(m; options)
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
        # LocalSearchSolvers._values!(s, Dictionary{Int,Int}())

        # display(solution(s))
        @info time_info(s)
        rm("info.json")
    end
end

@testset "Raw solver: sudoku" begin
    sudoku_instance = collect(Iterators.flatten([9 3 0 0 0 0 0 4 0
                                                 0 0 0 0 4 2 0 9 0
                                                 8 0 0 1 9 6 7 0 0
                                                 0 0 0 4 7 0 0 0 0
                                                 0 2 0 0 0 0 0 6 0
                                                 0 0 0 0 2 3 0 0 0
                                                 0 0 8 5 3 1 0 0 2
                                                 0 9 0 2 8 0 0 0 0
                                                 0 7 0 0 0 0 0 5 3]))

    s = solver(sudoku(3; start = sudoku_instance);
        options = Options(print_level = :minimal, iteration = Inf, time_limit = 10))
    display(Dictionary(1:length(sudoku_instance), sudoku_instance))
    solve!(s)
    display(solution(s))
    display(s.time_stamps)
end

@testset "Raw solver: golomb" begin
    s = solver(golomb(5); options = Options(print_level = :minimal, iteration = 1000))
    solve!(s)

    @info "Results golomb!"
    @info "Values: $(get_values(s))"
    @info "Sol (val): $(best_value(s))"
    @info "Sol (vals): $(!isnothing(best_value(s)) ? best_values(s) : nothing)"
end

@testset "Raw solver: mincut" begin
    graph = zeros(5, 5)
    graph[1, 2] = 1.0
    graph[1, 3] = 2.0
    graph[1, 4] = 3.0
    graph[2, 5] = 1.0
    graph[3, 5] = 2.0
    graph[4, 5] = 3.0
    s = solver(
        mincut(graph, source = 1, sink = 5), options = Options(print_level = :minimal))
    solve!(s)
    @info "Results mincut!"
    @info "Values: $(get_values(s))"
    @info "Sol (val): $(best_value(s))"
    @info "Sol (vals): $(!isnothing(best_value(s)) ? best_values(s) : nothing)"

    s = solver(mincut(graph, source = 1, sink = 5, interdiction = 1),
        options = Options(print_level = :minimal))
    solve!(s)
    @info "Results 1-mincut!"
    @info "Values: $(get_values(s))"
    @info "Sol (val): $(best_value(s))"
    @info "Sol (vals): $(!isnothing(best_value(s)) ? best_values(s) : nothing)"

    s = solver(mincut(graph, source = 1, sink = 5, interdiction = 2);
        options = Options(print_level = :minimal, time_limit = 15, iteration = Inf))
    # @info describe(s)
    solve!(s)
    @info "Results 2-mincut!"
    @info "Values: $(get_values(s))"
    @info "Sol (val): $(best_value(s))"
    @info "Sol (vals): $(!isnothing(best_value(s)) ? best_values(s) : nothing)"
    @info time_info(s)
end

@testset "Raw solver: chemical equilibrium" begin
    A = [2.0 1.0 0.0; 6.0 2.0 1.0; 1.0 2.0 4.0]
    B = [20.0, 30.0, 25.0]
    C = [-10.0, -8.0, -6.0]
    m = chemical_equilibrium(A, B, C)
    s = solver(m; options = Options(print_level = :minimal))
    solve!(s)
    display(solution(s))
    display(s.time_stamps)
end
