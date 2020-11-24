module LocalSearchSolvers

# Imports
import Dictionaries: Dictionary, Indices, insert!
import Base: ∈
import Lazy: @forward

# Exports internal
export domain, ∈, variable, constraint

# Exports error/predicate functions
export all_different

include("domain.jl")
include("variable.jl")
include("constraint.jl")

end
