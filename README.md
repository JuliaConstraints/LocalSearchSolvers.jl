# LocalSearchSolvers

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaConstraints.github.io/LocalSearchSolvers.jl/dev)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaConstraints.github.io/LocalSearchSolvers.jl/stable)
[![Build Status](https://github.com/JuliaConstraints/LocalSearchSolvers.jl/workflows/CI/badge.svg)](https://github.com/JuliaConstraints/LocalSearchSolvers.jl/actions)
[![codecov](https://codecov.io/gh/JuliaConstraints/LocalSearchSolvers.jl/branch/main/graph/badge.svg?token=4T0VEWISUA)](https://codecov.io/gh/JuliaConstraints/LocalSearchSolvers.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

LocalSearchSolvers.jl proposes sets of technical components of Constraint-Based Local Search (CBLS) solvers and combine them in various ways.

![](docs/src/img/sudoku3x3.png)

## Dependencies

This package makes use of several dependencies from the JuliaConstraints GitHub org:
- `ConstraintDomains.jl`: a domains back-end package for all JuliaConstraints front packages
- `Constraints.jl`: a constraints back-end package for all JuliaConstraints front packages
- `CompositionalNetworks.jl`: a module to learn error functions automatically given a *concept*
- `Garamon.jl` (incoming): geometrical constraints

## Features

- [ ] Resolution of problems
  - [x] SATisfaction
  - [x] OPTimisation (single-objective)
  - [ ] OPTimisation (multiple-objective)
- [ ] Domains
  - [x] Discrete domains (any type of numbers)
  - [ ] Continuous domains
  - [ ] Arbitrary Objects such as physical ones
- [ ] Parallelization
  - [x] Multithreading
  - [ ] Distributed
- [ ] Solvers
  - [x] Weak-tabu list (based on the method in GHOST, the C++ lib)
  - [ ] Adaptive Search
- [ ] Domain Specific Languages (DSL)
  - [x] Straight Julia
  - [ ] JuMP*ish*
  - [ ] MiniZinc
- [ ] Others
  - [ ] Dynamic problems
  - [ ] Neighbourhoud selection
  - [ ] Variable selection
  - [ ] Mixed-solvers/methods with learning 

## Contributing

Contributions to this package are more than welcome and can be arbitrarily, and not exhaustively, split as follows:
- All features mentioned above
- Adding new constraints and symmetries
- Adding new ICNs to learn error of existing constraints
- Creating other compositional networks which target other kind of constraints
- Just making stuff better, faster, user-friendlier, etc.

### Contact
Do not hesitate to contact me (@azzaare) or other members of JuliaConstraints on GitHub (file an issue), the julialang discourse forum, the julialang slack channel, the julialang zulip server, or the Human of Julia (HoJ) discord server.
