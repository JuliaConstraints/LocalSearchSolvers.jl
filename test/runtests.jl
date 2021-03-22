import ConstraintDomains
using ConstraintModels
using Constraints
using Dictionaries
using LocalSearchSolvers
using Test

const LS = LocalSearchSolvers

@testset "LocalSearchSolvers.jl" begin
    include("internal.jl")
    include("raw_solver.jl")
end
