# Variables

## Domains

In the `LocalSearchSolvers.jl` framework, a variable is mainly defined by its domain. A domain can be *continuous*, *discrete*, or *mixed*. All the domain implementation is available at [ConstraintDomains.jl](https://github.com/JuliaConstraints/ConstraintDomains.jl). 

Currently, only discrete domains are available.

Domains can be used both statically or dynamically. 

### JuMP syntax (recommended)

```julia
# free variable named x
@variable(model, x)

# free variables in a X vector
@varialbe(model, X[1:5])

# variables with discrete domain 1:9 in a matrix M
@variable(model, M[1:9,1:9] in DiscreteDomain(1:9))
```
