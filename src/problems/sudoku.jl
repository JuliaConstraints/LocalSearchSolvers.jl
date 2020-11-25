function sudoku(n::Int; start::Dictionary{Int, Int} = Dictionary{Int, Int}())
    N = n^2
    d = domain(Vector{Int}(1:N))

    p = Problem()

    # Add variables
    foreach(_ -> variable!(p, d), 1:(N^2))

    # Add constraints: line, columns; blocks
    foreach(i -> constraint!(p, all_different, Vector{Int}((i * N + 1):((i + 1) * N))), 0:(N - 1))
    foreach(i -> constraint!(p, all_different, [j * N + i for j in 0:(N - 1)]), 1:N)

    for i in 0:(n - 1)
        for j in 0:(n - 1)
            vars = Vector{Int}()
            for k in 1:n
                for l in 0:(n - 1)
                    push!(vars, (j * n + l) * N + i * n + k)
                end
            end
            constraint!(p, all_different, vars)
        end
    end

    # TODO: Insert starting values (assuming they are correct)
    # foreach(((k,v),) -> , pairs(start))
    
    return p
end