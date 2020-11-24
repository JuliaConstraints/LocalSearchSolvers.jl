module LocalSearchSolvers

# Imports
<<<<<<< HEAD
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
=======
import Dictionaries: Dictionary
import Base: ∈

# Exports
export domain, ∈

include("domain.jl")
>>>>>>> Test for domain types and methods. Added Dictionaries.jl

end
