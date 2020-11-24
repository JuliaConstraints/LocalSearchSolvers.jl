module LocalSearchSolvers

# Imports
import Dictionaries: Dictionary, Indices
import Base: ∈
import Lazy: @forward

# Exports
export domain, ∈, variable

include("domain.jl")
include("variable.jl")
include("constraint.jl")

end
