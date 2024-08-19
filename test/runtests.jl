using Distributed

import ConstraintDomains
import CompositionalNetworks
@everywhere using Constraints
using Dictionaries
@everywhere using LocalSearchSolvers

using ExplicitImports
using JET
using Test
using TestItemRunner

@everywhere const LS = LocalSearchSolvers

@testset "LocalSearchSolvers.jl" begin
    include("Aqua.jl")
    include("ExplicitImports.jl")
    include("JET.jl")
    include("TestItemRunner.jl")
    include("internal.jl")
    include("raw_solver.jl")
end
