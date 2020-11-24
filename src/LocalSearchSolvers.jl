module LocalSearchSolvers

# Imports
<<<<<<< HEAD
import Dictionaries: Dictionary, Indices, insert!
=======
import Dictionaries: Dictionary, Indices
>>>>>>> 894143126eeb306142474672e0b5ebc4601558e3
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
