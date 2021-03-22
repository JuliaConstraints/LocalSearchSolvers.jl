# Constraints

In the `LocalSearchSolvers.jl` framework, a constraint can be define using either a *concept* (a predicate over a set of variables) or an *error function*. Additionally some constraints are already defined in  [Constraints.jl](https://github.com/JuliaConstraints/Constraints.jl).

As the recommended usage is through the `CBLS.jl` package and the `JuMP.jl` interface, we provide the related documentation here.

## Predicates and Error Functions

```@docs
CBLS.Predicate
CBLS.Error
```

Finally, one can compute the error function from a concept automatically using Interpretable Compositional Networks (ICN). Automatic computation through the [CompositionalNetworks.jl](https://github.com/JuliaConstraints/CompositionalNetworks.jl) package will soon be added within the JuMP syntax. In the mean time, please use this dependency directly.

## Usual Constraints
Some usual constraints are already available directly through JuMP syntax. Do not hesitate to file an issue to include more usual constraints.

```@docs
CBLS.AllDifferent
CBLS.AllEqual
CBLS.AllEqualParam
CBLS.AlwaysTrue
CBLS.DistDifferent
CBLS.Eq
CBLS.Ordered
```


