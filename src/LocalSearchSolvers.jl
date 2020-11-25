module LocalSearchSolvers

# TODO: return types: nothing, ind for internals etc

# Imports
import Dictionaries: Dictionary, Indices, insert!, set!
import Base: ∈
import Lazy: @forward

# Exports internal
export constraint!, variable!, objective!, add!, add_var_to_cons!, add_value!
export delete!, delete_value!, delete_var_from_cons!
export domain, variable, constraint, objective
export Constraint, Objective, Variable
export length_var, length_cons, constriction, draw, ∈, describe
export get_variable, get_variables, get_constraint, get_constraints, get_objective, get_objectives

# Exports Problem
export Problem, sudoku

# Exports error/predicate functions
export all_different

# Exports Solver
export Solver

# Includes internal structures
include("domain.jl")
include("variable.jl")
include("constraint.jl")
include("objective.jl")

# Includes problems
include("problem.jl")
include("problems/sudoku.jl")

# Includes solvers
include("solver.jl")

end
