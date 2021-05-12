
using Distributed
# Add a process with two threads
addprocs(1; exeflags = "-t 2")
# addprocs(1)

import ConstraintDomains
using ConstraintModels
using Constraints
using Dictionaries
@everywhere using LocalSearchSolvers
using Test


@testset "Distributed" begin
    @test workers() == [2]
end



const LS = LocalSearchSolvers

@testset "LocalSearchSolvers.jl" begin
    # include("internal.jl")
    include("raw_solver.jl")
end
