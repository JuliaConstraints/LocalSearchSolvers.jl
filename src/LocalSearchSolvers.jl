module LocalSearchSolvers

# Imports
import Dictionaries: Dictionary, Indices, insert!, set!
import Base: ∈
import Lazy: @forward

# Exports internal
export constraint!, variable!, objective!, add!, delete!
export domain, variable, constraint, objective
export Problem, Constraint, Objective, Variable
export length_var, length_cons, constriction, draw, ∈, describe
export get_variable, get_variables, get_constraint, get_constraints, get_objective, get_objectives

# Exports error/predicate functions
export all_different

include("domain.jl")
include("variable.jl")
include("constraint.jl")
include("objective.jl")
include("problem.jl")

end
