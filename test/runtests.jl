using Distributed

import ConstraintDomains
import CompositionalNetworks
@everywhere using Constraints
using Dictionaries
@everywhere using LocalSearchSolvers
using Test

const LS = LocalSearchSolvers

@testset "LocalSearchSolvers.jl" begin
    include("internal.jl")
    include("raw_solver.jl")
end
