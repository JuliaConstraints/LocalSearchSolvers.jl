# Quick Start Guide
This section introduce the main concepts of `LocalSearchSolvers.jl`. We model both a satisfaction and an optimization version of the [Golomb Ruler](https://en.wikipedia.org/wiki/Golomb_ruler) problem.
For this quick-start, we will use [JuMP.jl](https://github.com/jump-dev/JuMP.jl) syntax.

## Golomb Ruler
From Wikipedia's English page.
> In mathematics, a Golomb ruler is a set of marks at integer positions along an imaginary ruler such that no two pairs of marks are the same distance apart. The number of marks on the ruler is its order, and the largest distance between two of its marks is its length. Translation and reflection of a Golomb ruler are considered trivial, so the smallest mark is customarily put at 0 and the next mark at the smaller of its two possible values.

![](img/Golomb_Ruler-4.svg)

### Satisfaction version
Given a number of marks `n` and a ruler length `L`, we can model our problem in Julia as easily as follows. First create an empty problem.

 ```julia
using LocalSearchSolvers # a CBLS alias is exported
using JuMP

model = Model(CBLS.Optimizer)
```

Then add `n` variables with domain `0:L`.

```julia
n = 4 # marks
L = n^2 # ruler length
@variable(model, X[1:n], DiscreteSet(0:L))
```

Finally add the following constraints,
* all marks have a different value
* marks are ordered (optional)
* finally, no two pairs of marks are the same distance apart

```julia
@constraint(model, X in AllDifferent()) # different marks
@constraint(model, X in Ordered()) # for output layout, keep them ordered

# No two pairs have the same length
for i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n
    (i, j) < (k, l) || continue
    @constraint(model, [X[i], X[j], X[k], X[l]] in DistDifferent())
end
```

### Optimization version
A Golomb ruler can be either optimally dense (maximal `m` for a given `L`) or optimally short (minimal `L` for a given `n`). Until `LocalSearchSolvers.jl` implements dynamic problems, only optimal shortness is provided.

The model objective is then to minimize the maximum distance between the two extrema marks in the ruler. As the domains are positive, we can simply minimize the maximum value.

```julia
@objective(model, Min, ScalarFunction(maximum))
```

### Ruling the solver
For either version, the solver is built and run in a similar way. Please note that the satisfaction one will stop if a solution is found. The other will run until the maximum number of iteration is reached (1000 by default).

```julia
optimize!(model)
```

And finally retrieve the (best-known) solution info.

```julia
result = value.(X)
@info "Golomb marks: $result"
```

Please note, that the Golomb Ruler is already implemented in the package as `golomb(n::Int, L::Int=n^2)`.

