module LocalSearchSolvers

# TODO: return types: nothing, ind for internals etc

# Imports
import Dictionaries: Dictionary, Indices, DictionaryView, insert!, set!
import Base: ∈, convert
import Lazy: @forward

# Exports internal
export constraint!, variable!, objective!, add!, add_var_to_cons!, add_value!
export delete!, delete_value!, delete_var_from_cons!
export domain, variable, constraint, objective
export Constraint, Objective, Variable
export length_var, length_cons, constriction, draw, ∈, describe
export get_variable, get_variables, get_constraint, get_constraints, get_objective, get_objectives
export get_cons_from_var, get_vars_from_cons, get_domain, get_name

# Exports Problem
export Problem, sudoku, golomb

# Exports error/predicate/objective functions
export all_different, dist_different
export dist_extrema

# Exports Solver
export Solver, solve!, specialize, specialize!, Settings

# Include utils
include("utils.jl")

# Include internal structures
include("domain.jl")
include("variable.jl")
include("constraint.jl")
include("objective.jl")

# Include solvers
include("problem.jl")
include("state.jl")
include("solver.jl")

# Include specific problems
include("problems/sudoku.jl")
include("problems/golomb.jl")
include("problems/cut.jl")

# Include usual constraints
include("constraints/all_different.jl")
include("constraints/dist_different.jl")

# Include usual objectives
include("objectives/extrema.jl")

end
