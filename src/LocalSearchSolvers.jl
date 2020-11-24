module LocalSearchSolvers

# Imports
import Dictionaries: Dictionary, Indices, insert!, set!
import Base: ∈
import Lazy: @forward

# Exports internal
export domain, ∈, variable, constraint, objective, Problem

# Exports error/predicate functions
export all_different

include("domain.jl")
include("variable.jl")
include("constraint.jl")
include("objective.jl")
include("problem.jl")

end
