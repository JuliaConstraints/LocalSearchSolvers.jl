# Variables

## Domains

In the `LocalSearchSolvers.jl` framework, a variable is mainly defined by its domain. A domain can be *continuous*, *discrete*, or *mixed*. All the domain implementation is available in `ConstraintDomains.jl`. 

Currently, only discrete domains are available.

Domains can be used both statically or dynamically. Please note that for efficiency purpose it is better to construct and use the same `domain` for a set of variables with the same mathematical domain. However, it might not be compatible with all dynamic models.

## Constructor
```@docs
LocalSearchSolvers.variable
```

