module LocalSearchSolvers

# Imports
import Dictionaries: Dictionary, Indices, insert!, set!
import Base: ∈
import Lazy: @forward

# Exports internal
export domain, ∈, variable, constraint, objective
export Problem, Constraint, Objective, Variable

# Exports error/predicate functions
export all_different

include("domain.jl")
include("variable.jl")
include("constraint.jl")
include("objective.jl")
include("problem.jl")

end
