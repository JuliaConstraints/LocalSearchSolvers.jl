```@meta
CurrentModule = LocalSearchSolvers
```

# Constraint-Based Local Search Framework

The **LocalSearchSolvers.jl** framework proposes sets of technical components of Constraint-Based Local Search (CBLS) solvers and combine them in various ways. Make your own CBLS solver!

<!-- TODO: what is a CBLS solver etc. -->

![](img/sudoku3x3.png)

### Dependencies

This package makes use of several dependencies from the JuliaConstraints GitHub org:
- [ConstraintDomains.jl](https://github.com/JuliaConstraints/ConstraintDomains.jl): a domains back-end package for all JuliaConstraints front packages
- [Constraints.jl](https://github.com/JuliaConstraints/Constraints.jl): a constraints back-end package for all JuliaConstraints front packages
- [CompositionalNetworks.jl](https://github.com/JuliaConstraints/CompositionalNetworks.jl): a module to learn error functions automatically given a *concept*
- [Garamon.jl](https://github.com/JuliaConstraints/Garamon.jl) (incoming): geometrical constraints
- [COPInstances.jl](https://github.com/JuliaConstraints/COPInstances.jl) (incoming): a package to store, download, and generate combinatorial optimization instances 

It also relies on great packages from the julialang ecosystem, among others,
- [ModernGraphs.jl](https://github.com/Humans-of-Julia/ModernGraphs.jl) (incoming): a dynamic multilayer framework for complex graphs which allows a fine exploration of entangled neighborhoods
- [JuMP.jl](https://github.com/jump-dev/JuMP.jl): a rich interface for optimization solvers

### Features

Wanted features list:
- **Strategies**
  - [ ] *Move*: local move, permutation between `n` variables
  - [ ] *Neighbor*: simple or multiplexed neighborhood, dimension/depth
  - [ ] *Objective(s)*: single/multiple objectives, Pareto, etc.
  - [ ] *Parallelisation*: distributed and multithreaded, HPC clusters
  - [ ] *Perturbation*: dynamicity, restart, pool of solutions
  - [ ] *Portfolio*: portfolio of solvers, partition in subproblems
  - [ ] *Restart*
    - [x] restart sequence
    - [ ] partial/probabilistic restart (in coordination with perturbation strategies)
  - [ ] *Selection* of variables: roulette selection, multi-variables, meta-variables (cf subproblem)
  - [ ] *Solution(s)*: management of pool, best versus diverse
  - *Tabu*
    - [x] No Tabu
    - [x] Weak-tabu
    - [x] Keen-tabu
  - *Termination*: when, why, how, interactive, results storage (remote)
- **Featured startegies**
  - [ ] Adaptive search
  - [ ] Extremal optimization
- **Others**
  - [ ] Resolution of problems
    - [x] SATisfaction
    - [x] OPTimisation (single-objective)
    - [ ] OPTimisation (multiple-objective)
    - [ ] Dynamic problems
  - [ ] Domains
    - [x] Discrete domains (any type of numbers)
    - [x] Continuous domains
    - [ ] Arbitrary Objects such as physical ones
  - [ ] Parallelization
    - [x] Multithreading
    - [ ] Distributed
    - [ ] Asynchronicity (for dynamic problems)
  - [ ] Domain Specific Languages (DSL)
    - [x] Straight Julia `:raw`
    - [x] JuMP*ish* | MathOptInterface.jl
    - [ ] MiniZinc
    - [ ] OR-tools ?
  - [ ] Learning settings (To be incorporated in [MetaStrategist.jl](https://github.com/JuliaConstraints/MetaStrategist.jl))
    - [x] Compositional Networks (error functions, cost functions)
    - [ ] Reinforcement learning for above mentioned learning features
    - [ ] Automatic benchmarking and learning from all the possible parameter combination (instance, model, solver, size, restart, hardware, etc.)

### Contributing

Contributions to this package are more than welcome and can be arbitrarily, and not exhaustively, split as follows:
- All features mentioned above
- Adding new constraints and symmetries
- Adding new problems and instances
- Adding new ICNs to learn error of existing constraints
- Creating other compositional networks which target other kind of constraints
- Just making stuff better, faster, user-friendlier, etc.

#### Contact
Do not hesitate to contact me (@azzaare) or other members of JuliaConstraints on GitHub (file an issue), the julialang [Discourse](discourse.julialang.org
) forum, the julialang [Slack](https://julialang.org/slack/) workspace, the julialang [Zulip](https://julialang.zulipchat.com/) server (*Constraint Programming* stream), or the Humans of Julia [Humans-of-Julia](https://humansofjulia.org/) discord server(*julia-constraint* channel).
