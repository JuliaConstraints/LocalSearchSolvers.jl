module LocalSearchSolvers

import Base.Threads: @threads, Atomic, nthreads, atomic_or!
import CompositionalNetworks
import ConstraintDomains: ConstraintDomains, AbstractDomain, ContinuousDomain, domain
import Constraints
import Dictionaries: Dictionaries, DictionaryView, Dictionary, Indices, set!
import Distributed: RemoteChannel, Future, workers, nworkers
import JSON
import Lazy: @forward
import TestItems: @testitem

#SECTION - Exports
export add!, delete!
export best_value, best_values
export constraint, constraint!
export domain
export get_values
export model
export objective, objective!
export solution
export solver, solve!
export time_info
export variable, variable!

export Options

# Include utils
include("utils.jl")

# Include model related files
include("variable.jl")
include("constraint.jl")
include("objective.jl")
include("model.jl")

# Include solver state and pool of configurations related files
include("configuration.jl")
include("pool.jl")
include("fluct.jl")
include("state.jl")

# Include strategies
include("strategies/move.jl")
include("strategies/neighbor.jl")
include("strategies/objective.jl")
include("strategies/parallel.jl")
include("strategies/perturbation.jl")
include("strategies/portfolio.jl")
include("strategies/tabu.jl") # precede restart.jl
include("strategies/restart.jl")
include("strategies/selection.jl")
include("strategies/solution.jl")
include("strategies/termination.jl")
include("strategy.jl") # meta strategy methods and structures

# Include solvers
include("options.jl")
include("time_stamps.jl")
include("solver.jl")
include("solvers/sub.jl")
include("solvers/meta.jl")
include("solvers/lead.jl")
include("solvers/main.jl")

# Include usual objectives
include("objectives/extrema.jl")
include("objectives/cut.jl")

end
