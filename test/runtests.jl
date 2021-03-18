import ConstraintDomains
using Dictionaries
using LocalSearchSolvers
using Test

import Constraints: usual_constraints, error_f

const LS = LocalSearchSolvers

@testset "LocalSearchSolvers.jl" begin
    include("internal.jl")
    include("raw_solver.jl")
    include("MOI_wrapper.jl")
    include("JuMP.jl")
end
