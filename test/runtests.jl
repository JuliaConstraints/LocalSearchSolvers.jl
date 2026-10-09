using Distributed

import ConstraintDomains
import CompositionalNetworks
@everywhere using Constraints
using Dictionaries
@everywhere using LocalSearchSolvers
using Test
using TestItemRunner
using TestItems

const LS = LocalSearchSolvers

@testset "LocalSearchSolvers.jl" begin
    include("diagnostics.jl")
    include("solution_regressions.jl")
    include("pool_concurrency.jl")
    include("solution_snapshots.jl")
    include("performance_contracts.jl")
    include("prepared_workspace_regressions.jl")
    include("proposal_strategies.jl")
    include("meta_move_constructors.jl")
    include("integer_invariant_refresh.jl")
    include("Aqua.jl")
    include("TestItemRunner.jl")
    include("internal.jl")
    include("raw_solver.jl")
end
