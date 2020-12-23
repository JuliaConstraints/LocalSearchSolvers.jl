# Quick Start Guide
This section introduce the main concepts of `LocalSearchSolvers.jl`. We model both a satisfaction and an optimization version of the [Golomb Ruler](https://en.wikipedia.org/wiki/Golomb_ruler) problem.

## Golomb Ruler
From Wikipedia's English page.
> In mathematics, a Golomb ruler is a set of marks at integer positions along an imaginary ruler such that no two pairs of marks are the same distance apart. The number of marks on the ruler is its order, and the largest distance between two of its marks is its length. Translation and reflection of a Golomb ruler are considered trivial, so the smallest mark is customarily put at 0 and the next mark at the smaller of its two possible values.

![](img/Golomb_Ruler-4.svg)

### Satisfaction version
Given a number of marks `n` and a ruler length `L`, we can model our problem in Julia as easily as follows. First create an empty problem.

 ```julia
model = Model()
```

Then add `n` variables with domain `d`.

```julia
d = domain(0:L)
foreach(_ -> variable!(model, d), 1:n)
```

Finally add the following constraints,
* all marks have a different value
* first mark has value 0
* finally, no two pairs of marks are the same distance appart

```julia
constraint!(model, c_all_different, 1:n)
constraint!(model, x -> c_all_equal_param(x; param = 0), 1:1)
for i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n
    (i, j) < (k, l) || continue
    constraint!(model, c_dist_different, [i, j, k, l])
end
```

### Optimization version
A Golomb ruler can be either optimally dense (maximal `m` for a given `L`) or optimally short (minimal `L` for a given `n`). Until `LocalSearchSolvers.jl` implements dynamic problems, only optimal shortness is provided.

The model objective is then to minimize the maximum distance between the two extrema marks in the ruler.

```julia
objective!(model, o_dist_extrema)
```

### Ruling the solver
For either version, the solver is built and run in a similar way. Please note that the satisfaction one will stop if a solution is found. The other will run until the maximum number of iteration is reached.

```julia
s = Solver(model)
solve!(s)
```

And finally retrieve the (best-known) solution info. (TODO: make it julian and clean)

```julia
@info "Results golomb!"
@info "Values: $(s.state.values)"
@info "Sol (val): $(s.state.best_solution_value)"
@info "Sol (vals): $(!isnothing(s.state.best_solution_value) ? s.state.best_solution : nothing)"
```

Please note, that the Golomb Ruler is already implemented in the package as `golomb(n::Int, L::Int=n^2)`. An hand-made printing function is also there: `TODO:`.

