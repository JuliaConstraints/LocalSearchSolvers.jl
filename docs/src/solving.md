# Modeling and solving

Ideally, given a problem, one just want to model and solve. That is what *LocalSearchSolvers* is aiming for. Here we only provide JuMP syntax.

## Model
```julia
using LocalSearchSolvers, JuMP

model = Model(CBLS.Optimizer) # CBLS is an exported alias of LocalSearchSolvers

# add variables (cf Variables section)
# add constraints (cf Constraints section)
# add objective (cf Objectives section)
```

## Solver

```julia
# run the solver. If no objectives are provided, it will look for a satisfying solution and stop
optimize!(model)

# extract the values (assuming X, a (collection of) variable(s) is the target)
solution = value.(X)
```

### Solver options

```@docs
LocalSearchSolvers.Options
```
