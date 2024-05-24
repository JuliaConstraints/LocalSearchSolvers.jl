using BenchmarkTools
using LocalSearchSolvers

const suite = BenchmarkGroup()

suite["adaptive"] = BenchmarkGroup(["integer", "discrete", "all different"])

# bench for the error functions and predicate of usual constraints
suite["constraints"] = BenchmarkGroup(["error", "predicate", "automatic", "handmade"])
for c in [all_different]
    for i in 0:10
        n = 2^i
        values = rand(1:2n, n)
        suite["constraints"][string(c), length(values)] = @benchmarkable $(c)($values...)
    end
end

# bench for the different problems modeling
suite["problems"] = BenchmarkGroup(["generation"])
for p in [sudoku]
    for size in 2:10
        suite["problems"][string(p), size] = @benchmarkable $(p)($size)
    end
end

## commands to store the tuning parameters
# tune!(suite)
# BenchmarkTools.save("benchmark/params.json", params(suite));

## syntax is loadparams!(group, paramsgroup, fields...)
# loadparams!(suite, BenchmarkTools.load("benchmark/params.json")[1], :evals, :samples);

results = run(suite, verbose=true, seconds=1)
