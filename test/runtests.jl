using LocalSearchSolvers
using Dictionaries
using Test

import Constraints: usual_constraints, error_f

@testset "LocalSearchSolvers.jl" begin
    include("internal.jl")
    include("problems.jl")
    include("functions.jl")
end
