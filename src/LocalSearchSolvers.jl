module LocalSearchSolvers

using Base.Threads
using CompositionalNetworks
using ConstraintDomains
using Constraints
using Dictionaries
using Distributed
using JSON
using Lazy

# Exports internal
export constraint!, variable!, objective!, add!, add_var_to_cons!, add_value!
export delete_value!, delete_var_from_cons!, domain, variable, constraint, objective
export length_var, length_cons, constriction, draw, describe, get_variable
export get_variables, get_constraint, get_constraints, get_objective, get_objectives
export get_cons_from_var, get_vars_from_cons, get_domain, get_name, solution

# export for CBLS.jl
export _set_domain!, is_sat, max_domains_size, get_value, update_domain!, has_solution
export set_option!, get_option, sense, sense!

# Exports Model
export model

# Exports error/predicate/objective functions
export o_dist_extrema, o_mincut

# Exports Solver
export solver, solve!, specialize, specialize!, Options, get_values, best_values
export best_value, time_info, status

# Include utils
include("utils.jl")

# Include model related files
include("variable.jl")
include("constraint.jl")
include("objective.jl")
include("model.jl")

# Include solver state and pool of configurations related files
include("configuration.jl")
include("pool.jl")
include("state.jl")

# Include strategies
include("strategies/move.jl")
include("strategies/neighbor.jl")
include("strategies/objective.jl")
include("strategies/parallel.jl")
include("strategies/perturbation.jl")
include("strategies/portfolio.jl")
include("strategies/tabu.jl") # preceed restart.jl
include("strategies/restart.jl")
include("strategies/selection.jl")
include("strategies/solution.jl")
include("strategies/termination.jl")
include("strategy.jl") # meta strategy methods and structures

# Include solvers
include("options.jl")
include("time_stamps.jl")
include("solver.jl")

# Include usual objectives
include("objectives/extrema.jl")
include("objectives/cut.jl")

end
