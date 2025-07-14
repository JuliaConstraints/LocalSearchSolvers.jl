using Distributed

import ConstraintDomains
import CompositionalNetworks
@everywhere using Constraints
using Dictionaries
using Intervals
@everywhere using LocalSearchSolvers
using Test
using TestItemRunner
using TestItems

const LS = LocalSearchSolvers

@testset "LocalSearchSolvers.jl" begin
    include("Aqua.jl")
    include("TestItemRunner.jl")
    include("internal.jl")
    include("raw_solver.jl")
end
