problems = [
    sudoku(2),
]

for p in problems
    println(describe(p))
    s = Solver{Int}(p)
end