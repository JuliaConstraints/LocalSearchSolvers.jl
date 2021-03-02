module LocalSearchSolvers

# TODO: return types: nothing, ind for internals etc

# Usings
using MathOptInterface

# Imports
import Dictionaries: Dictionary, Indices, DictionaryView, insert!, set!, empty!
import Base: ∈, convert, copy
import Base.Threads: nthreads, @threads, Atomic, atomic_or!
import Lazy: @forward
import Constraints: usual_constraints, error_f
import CompositionalNetworks: optimize!, csv2space, compose, ICN
import ConstraintDomains: AbstractDomain, EmptyDomain, domain, _add!, _delete!, _draw, _length
import ConstraintDomains: _get, _get_domain, _domain_size
import Dates: Time, Nanosecond
import JuMP
import JuMP: @constraint, @variable, @objective, VariableRef, index

# Const
const CBLS = LocalSearchSolvers
const MOI = MathOptInterface
const MOIU = MOI.Utilities

# Exports internal
export constraint!, variable!, objective!, add!, add_var_to_cons!, add_value!
export delete!, delete_value!, delete_var_from_cons!
export domain, variable, constraint, objective
export length_var, length_cons, constriction, draw, ∈, describe
export get_variable, get_variables, get_constraint, get_constraints, get_objective, get_objectives
export get_cons_from_var, get_vars_from_cons, get_domain, get_name, solution

# Exports Model
export model, sudoku, golomb, mincut, magic_square

# Exports error/predicate/objective functions
export o_dist_extrema, o_mincut

# Exports Solver
export solver, solve!, specialize, specialize!, Options
export get_values, best_values, best_value

# Export MOI/JuMP
export CBLS
export DiscreteSet, Predicate, Error, ScalarFunction
export AllDifferent, AllEqual, AllEqualParam, Eq, DistDifferent, AlwaysTrue, Ordered

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
include("state.jl")

# Include strategies
include("strategies/move.jl")
include("strategies/neighbor.jl")
include("strategies/objective.jl")
include("strategies/parallel.jl")
include("strategies/perturbation.jl")
include("strategies/portfolio.jl")
include("strategies/tabu.jl") # preceed restart.jl
include("strategies/restart.jl")
include("strategies/selection.jl")
include("strategies/solution.jl")
include("strategies/termination.jl")
include("strategy.jl") # meta strategy methods and structures

# Include solvers
include("options.jl")
include("solver.jl")

# Include MOI/JuMP
include("MOI_wrapper/MOI_wrapper.jl")
include("MOI_wrapper/variables.jl")
include("MOI_wrapper/constraints.jl")
include("MOI_wrapper/objectives.jl")
include("MOI_wrapper/results.jl")

# Include usual objectives
include("objectives/extrema.jl")
include("objectives/cut.jl")

# Include specific models
include("models/cut.jl")
include("models/golomb.jl")
include("models/magic_square.jl")
include("models/sudoku.jl")

end
