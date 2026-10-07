module LocalSearchSolvers

# Implemented by the optional MetaStrategist extension.
function strategy_catalog end
function materialize_strategy end
function execution_builder end
function take_strategy_events! end
function prepare_unit end
function run_episode! end
function reset_unit! end
function reconfigure_unit! end
function snapshot_unit end
function restore_unit! end
function unit_receipt end
function suspend! end
function resume_unit! end
function release_unit! end
export resume_unit!, release_unit!
function strategy_descriptor end
export strategy_descriptor
export prepare_unit, run_episode!, reset_unit!, reconfigure_unit!, snapshot_unit, restore_unit!, unit_receipt, suspend!, model_revision
export strategy_catalog, materialize_strategy, execution_builder, take_strategy_events!

using Base.Threads
using CompositionalNetworks
using ConstraintDomains
using Constraints
using Dates
using Dictionaries
using Distributed
using JSON
using Lazy
using Logging
using Printf
using ProgressBars
using ProgressMeter
using Random
using Term
using TestItems

# Exports internal
export constraint!, variable!, objective!, add!, add_var_to_cons!, add_value!
export delete_value!, delete_var_from_cons!, domain, variable, constraint, objective
export length_var, length_cons, constriction, draw, describe, get_variable
export get_variables, get_constraint, get_constraints, get_objective, get_objectives
export get_cons_from_var, get_vars_from_cons, get_domain, get_name, solution

# export for CBLS.jl
export _set_domain!, is_sat, max_domains_size, get_value, update_domain!, has_solution
export set_option!, get_option, sense, sense!

# Exports Model
export model

# Exports typed move and neighborhood protocols
export AbstractMove, AssignMove, SequenceEditMove, SetEditMove, SwapMove
export AbstractAcceptanceStrategy, AbstractVariableSelector
export AbstractMetaVariable, AbstractMetaVariableResolver, AbstractNeighborhoodGenerator
export AssignSwapNeighborhood, BestImprovingAcceptance, DepthSchedule, MetaMove,
       MetaStrategy
export RestartPolicy, restart_policy
export NativeDecisionNeighborhood
export MetaVariable, MetaVariableRequest, NeighborhoodRequest, WorstVariableSelector
export affected_variables, generate_moves, generate_moves!, meta_variable, meta_variable_id,
       move_depth
export candidate_relation, compatibility_depths, resolve_meta_variable, scope,
       select_target,
       value_after, edit_distance, edit_kind

# Exports error/predicate/objective functions
export o_dist_extrema, o_mincut

# Exports Solver
export solver, solve!, specialize, specialize!, Options, get_values, best_values
export best_value, iterations, time_info, status

# Exports Logger
export LogLevel, ProgressMode, ProgressTracker, ProgressMeterTracker, LoggerConfig
export configure_logger, log_error, log_warn, log_info, log_debug
export update_progress!, reset_progress!, enable_progress!, set_progress_mode!
export display_progress!, finalize_progress!, format_progress_bar
export default_log_file_path
export @ls_debug, @ls_info, @ls_warn, @ls_error
export LSLoggerAdapter, convert_log_level, convert_to_logging_level

# Include utils and interfaces
include("utils.jl")
include("logger_interface.jl")
include("diagnostics.jl")

# Include options first since it's used by logger
include("options.jl")

# Include logger files to make macros available
include("logger/types.jl")
include("logger/config.jl")
include("logger/progress.jl")
include("logger/display.jl")
include("logger/distributed.jl")
include("logger/progress_meter.jl")
include("logger/logging_adapter.jl")
include("logger/macros.jl")
include("logger/logger.jl")

# Include model related files
include("variable.jl")
include("constraint.jl")
include("objective.jl")
include("strategies/move.jl") # move types are used by compiled model evaluation
include("strategies/meta_variable.jl")
include("model.jl")

# Include solver state and pool of configurations related files
include("configuration.jl")
include("pool.jl")
include("fluct.jl")
include("state.jl")

# Include strategies
include("strategies/neighbor.jl")
include("strategies/compound.jl")
include("strategies/acceptance.jl")
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
include("time_stamps.jl")
include("solver.jl")
include("strategies/proposals.jl")
include("solvers/sub.jl")
include("solvers/meta.jl")
include("solvers/lead.jl")
include("solvers/main.jl")

# Include usual objectives
include("objectives/extrema.jl")
include("objectives/cut.jl")

end
