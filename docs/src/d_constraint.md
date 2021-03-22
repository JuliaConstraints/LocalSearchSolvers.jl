# Constraints.jl

A  back-end package for JuliaConstraints front packages, such as `LocalSearchSolvers.jl`.

It provides the following features:
- A dictionary to store usual constraint: `usual_constraint`, which contains the following entries
  - `:all_different`
  - `:dist_different`
  - `:eq`, `:all_equal`, `:all_equal_param`
  - `:ordered`
  - `:always_true` (mainly for testing default `Constraint()` constructor)
- For each constraint `c`, the following properties
  - arguments length
  - concept (predicate the variables compliance with `c`)
  - error (a function that evaluate how much `c` is violated)
  - parameters length
  - known symmetries of `c`
- A learning function using `CompositionalNetworks.jl`. If no error function is given when instantiating `c`, it will check the existence of a composition related to `c` and set the error to it.

Follow the list of the constraints currently stored in `usual_constraint`. Note that if the constraint is named `_my_constraint`, it can be accessed as `usual_constraint[:my_constraint]`.

```@docs
Constraints.all_different
Constraints.all_equal
Constraints.all_equal_param
Constraints.dist_different
Constraints.eq
Constraints.ordered
```

```@autodocs
Modules = [Constraints]
Private = false
```