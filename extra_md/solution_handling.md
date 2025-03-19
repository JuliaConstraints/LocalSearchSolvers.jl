# Solution Handling in LocalSearchSolvers

This document explains the logic behind solution handling, phase transitions, and pool updates in the LocalSearchSolvers package.

## Core Components

### Configuration

The `Configuration` struct is the fundamental unit that represents a potential solution:

```julia
mutable struct Configuration{T}
    solution::Bool    # Flag indicating if this is a solution
    value::Float64    # Cost/objective value
    values::Dictionary{Int, T}  # Variable assignments
end
```

- `solution`: Boolean flag directly indicating if this configuration is a solution
- `value`: For satisfaction problems, represents the error (0.0 for solutions); for optimization problems, represents the objective value
- `values`: The actual variable assignments

### Pool

The `Pool` maintains the best configurations found during solving:

```julia
mutable struct _Pool{T} <: AbstractPool
    best::Int  # Index of best configuration
    configurations::Vector{Configuration{T}>  # All stored configurations
    status::PoolStatus
    value::Float64  # Value of best configuration
end
```

- Solution status is checked via `has_solution(pool)`, which delegates to `is_solution(best_config(pool))`
- Best values are accessed via `best_values(pool)`

### State

The solver's `State` maintains the current configuration and related information:

```julia
mutable struct _State{T} <: AbstractState
    configuration::Configuration{T}  # Current configuration
    # ... other fields
    optimizing::Bool  # Whether in optimization phase
end
```

- Solution status is checked via `has_solution(s::_State)`, which delegates to `is_solution(s.configuration)`
- The `optimizing` flag indicates whether we're in optimization phase

## Solution Detection

A configuration is considered a solution when:

1. During creation:
   ```julia
   # In Configuration constructor
   val = compute_costs(m, values, X)
   sol = val ≈ 0.0  # Solution if error is approximately zero
   ```

2. During solving:
   ```julia
   # In set_error!
   function set_error!(s::_State, err)
       sat = err ≈ 0.0
       set_sat!(s, sat)  # Update solution flag
       !sat && set_value!(s, err)
   end
   ```

## Phase Transitions

The solver operates in two phases:
1. **Satisfaction Phase**: Finding any valid solution
2. **Optimization Phase**: Improving the objective value of solutions

### Transition Logic

The transition from satisfaction to optimization occurs in `_step!`:

```julia
if _compute!(s)  # Returns true when a solution is found
    if !is_sat(s)  # If this is an optimization problem
        _optimizing!(s)  # Switch to optimization phase
        _verbose(s, "Switching to optimization")
    else
        _verbose(s, "Solution found, pool has_solution=$(has_solution(s))")
        return true
    end
end
```

Key points:
- We only transition to optimization phase after finding a first solution
- For satisfaction problems, we return immediately after finding a solution
- For optimization problems, we continue searching to improve the objective value

## Pool Updates

The pool is updated at several key points:

### 1. Initialization

```julia
# In _init!
function _init!(s, ::Val{:local})
    # ... other initialization
    state!(s)
    pool!(s)  # Initialize pool with current state
    return has_solution(s)
end
```

### 2. During Local Moves

```julia
# In _move!
if cost == 0 && is_sat(s)
    s.pool = pool(s.state.configuration)  # Update pool when solution found
    return best_values, best_swap, tabu
end
```

### 3. During Cost Computation

```julia
# In _compute!
if get_error(s) == 0.0  # If solution found
    _optimizing(s) && _compute_objective!(s, o)  # If optimizing, compute objective
    is_sat(s) && (s.pool = pool(s.state.configuration))  # If satisfaction problem, update pool
    return true
end
```

### 4. During Objective Computation

```julia
# In _compute_objective!
function _compute_objective!(s, o::Objective)
    val = sense(s) * apply(o, _values(s).values)
    set_value!(s, val)
    if is_empty(s.pool) || val < best_value(s)  # If pool empty or value improved
        s.pool = pool(s.state.configuration)  # Update pool
    end
end
```

## Solution Flow in Main Solver

For the main solver (without distributed or threaded solvers):

1. **Initialization**: Pool is created with initial state
2. **Solving Loop**:
   - Each step attempts to improve the current configuration
   - When a solution is found, it's stored in the pool
   - For optimization problems, we transition to optimization phase and continue improving
3. **Termination**:
   - For satisfaction problems: Stop when any solution is found
   - For optimization problems: Continue until time/iteration limits are reached

## Remote Solution Handling

When using distributed solvers (not covered in current tests):

1. Each remote solver maintains its own pool
2. The main solver periodically checks for solutions from remote solvers
3. Solutions are communicated via remote channels (`rc_sol`, `rc_report`)
4. The main solver updates its pool with remote solutions via `update_pool!`

```julia
function update_pool!(s, pool)
    is_empty(pool) && return nothing
    if is_sat(s) || best_value(s) > best_value(pool)
        s.pool = deepcopy(pool)
    end
end
```
