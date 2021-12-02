using PerfChecker
using Test

using LocalSearchSolvers
using ConstraintDomains
using Constraints
using CompositionalNetworks
using PatternFolds

@testset "LocalSearchSolvers (PerfChecker)" begin
    title = "Check the performance of LocalSearchSolvers"

    dependencies = [
        PatternFolds,
        ConstraintDomains,
        CompositionalNetworks,
        Constraints,
        LocalSearchSolvers,
    ]

    targets = [
        PatternFolds,
        ConstraintDomains,
        CompositionalNetworks,
        Constraints,
        LocalSearchSolvers,
    ]

    sudoku_instance = collect(
        Iterators.flatten(
            [
                9 3 0 0 0 0 0 4 0
                0 0 0 0 4 2 0 9 0
                8 0 0 1 9 6 7 0 0
                0 0 0 4 7 0 0 0 0
                0 2 0 0 0 0 0 6 0
                0 0 0 0 2 3 0 0 0
                0 0 8 5 3 1 0 0 2
                0 9 0 2 8 0 0 0 0
                0 7 0 0 0 0 0 5 3
            ],
        ),
    )

    function n_queens(n)
        m = model(; kind=:nqueens)
        d = domain(1:n)

        foreach(_ -> variable!(m, d), 1:n)

        e =
            (x; param=nothing, dom_size=n) -> error_f(usual_constraints[:all_different])(
                x; param=param, dom_size=dom_size
            )

        constraint!(m, e, 1:n)

        e1(x) = Float64(!(x[1] != x[2]))
        e2(x, i, j) = Float64(!(x[1] != x[2] + i - j))
        e3(x, i, j) = Float64(!(x[1] != x[2] + j - i))

        for i in 1:n, j in (i + 1):n
            constraint!(m, e1, [i, j])
            constraint!(m, x -> e2(x, i, j), [i, j])
            constraint!(m, x -> e3(x, i, j), [i, j])
        end

        return m
    end

    graph = zeros(5, 5)
    graph[1, 2] = 1.0
    graph[1, 3] = 2.0
    graph[1, 4] = 3.0
    graph[2, 5] = 1.0
    graph[3, 5] = 2.0
    graph[4, 5] = 3.0

    function mincut(graph; source, sink, interdiction=0)
        m = model(; kind=:cut)
        n = size(graph, 1)

        d = domain(0:n)

        separator = n + 1 # value that separate the two sides of the cut

        # Add variables:
        foreach(_ -> variable!(m, d), 0:n)

        # Extract error function from usual_constraint
        e1 =
            (x; param=nothing, dom_size=n + 1) ->
                error_f(usual_constraints[:ordered])(x; param, dom_size)
        e2 =
            (x; param=nothing, dom_size=n + 1) ->
                error_f(usual_constraints[:all_different])(x; param, dom_size)

        # Add constraint
        constraint!(m, e1, [source, separator, sink])
        constraint!(m, e2, 1:(n + 1))

        # Add objective
        objective!(m, (x...) -> o_mincut(graph, x...; interdiction))

        return m
    end

    function golomb(n, L=n^2)
        m = model(; kind=:golomb)

        # Add variables
        d = domain(0:L)
        foreach(_ -> variable!(m, d), 1:n)

        # Extract error function from usual_constraint
        e1 =
            (x; param=nothing, dom_size=n) ->
                error_f(usual_constraints[:all_different])(x; param, dom_size)
        e2 =
            (x; param=nothing, dom_size=n) ->
                error_f(usual_constraints[:all_equal_param])(x; param, dom_size)
        e3 =
            (x; param=nothing, dom_size=n) ->
                error_f(usual_constraints[:dist_different])(x; param, dom_size)

        # # Add constraints
        constraint!(m, e1, 1:n)
        constraint!(m, x -> e2(x; param=0), 1:1)
        for i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n
            (i, j) < (k, l) || continue
            constraint!(m, e3, [i, j, k, l])
        end

        # Add objective
        objective!(m, o_dist_extrema)

        return m
    end

    function sudoku(n; start=nothing)
        N = n^2
        d = domain(1:N)

        m = model(; kind=:sudoku)

        # Add variables
        if isnothing(start)
            foreach(_ -> variable!(m, d), 1:(N^2))
        else
            foreach(((x, v),) -> variable!(m, 1 ≤ v ≤ N ? domain(v) : d), pairs(start))
        end

        e =
            (x; param=nothing, dom_size=N) -> error_f(usual_constraints[:all_different])(
                x; param=param, dom_size=dom_size
            )

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

    function pre_alloc()
        # s = solver(sudoku(3; start=sudoku_instance); options=Options(; time_limit=60))
        s = solver(n_queens(16); options=Options(; time_limit=60))

        @info "Starting n-queens pre_alloc"
        solve!(s)
        @info time_info(s)
    end

    function alloc()
        s = solver(n_queens(16); options=Options(; iteration=10))

        @info "Starting n-queens alloc check"
        solve!(s)
        @info time_info(s)

        return nothing
    end

    alloc_check(title, dependencies, targets, pre_alloc, alloc; path=@__DIR__)
end
