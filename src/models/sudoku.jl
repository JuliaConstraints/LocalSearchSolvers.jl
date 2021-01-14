function sudoku(n::Int; start::Dictionary{Int,Int}=Dictionary{Int,Int}())
    N = n^2
    d = domain(1:N)

    m = Model()

    # Add variables
    foreach(_ -> variable!(m, d), 1:(N^2))

    err = (x; param=nothing, dom_size=N) -> error_f(
        usual_constraints[:all_different])(x; param=param, dom_size=dom_size
    )

    # Add constraints: line, columns; blocks
    foreach(i -> constraint!(m, err, (i * N + 1):((i + 1) * N)), 0:(N - 1))
    foreach(i -> constraint!(m, err, [j * N + i for j in 0:(N - 1)]), 1:N)

    for i in 0:(n - 1)
        for j in 0:(n - 1)
            vars = Vector{Int}()
            for k in 1:n
                for l in 0:(n - 1)
                    push!(vars, (j * n + l) * N + i * n + k)
                end
            end
            constraint!(m, err, vars)
        end
    end

    # TODO: Insert starting values (assuming they are correct)
    # foreach(((k,v),) -> , pairs(start))

    return m
end

# TODO: make a generic print problem function with :sudoku
# function _print_sudoku(s::Solver)
#     N = length_vars(s)
#     n = Int(√N)
#     str = ""
#     for j in 0:(n - 1)
#         aux = ""
#         for i in 1:n
#             v = _value(s, i + n * j)
#             aux *= "$v | "
#         end
#         str *= aux[1:(end - 3)] * "\t"
#         aux = ""
#         for i in 1:n
#             v = _var_cost(s, i + n * j)
#             aux *= "$v | "
#         end
#         str *= aux[1:(end - 3)] * "\n"
#         l = 4 * n + length(aux[1:(end - 3)])
#         str *= j == n - 1 ? "" : repeat("-", l) * "\n"
#     end
#     println(str)
# end
