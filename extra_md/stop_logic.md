# Solver Stopping Logic

## Variables

- `I` = First element of iteration tuple (true/false) - Stop on iteration limit only if solution found
- `L` = Reached iteration limit (true/false)
- `S` = Has solution (true/false)
- `T` = First element of time limit tuple (true/false) - Stop on time limit only if solution found
- `TL` = Reached time limit (true/false)

## Configuration
```julia
const stopping_configs = Dict{Symbol, NamedTuple{(:iteration, :time_limit), Tuple{Tuple{Bool, Int}, Tuple{Bool, Float64}}}}(
    :basic => (
        iteration = (false, 10),     # Stop at 10 iterations regardless of solution
        time_limit = (false, 1.0)    # Stop at 1 second regardless of solution
    ),
    :iter_with_sol => (
        iteration = (true, 10),      # Stop at 10 iterations only if solution found
        time_limit = (false, 1.0)    # Stop at 1 second regardless of solution
    ),
    :time_with_sol => (
        iteration = (false, 10),     # Stop at 10 iterations regardless of solution
        time_limit = (true, 1.0)     # Stop at 1 second only if solution found
    ),
    :both_with_sol => (
        iteration = (true, 10),      # Stop at 10 iterations only if solution found
        time_limit = (true, 1.0)     # Stop at 1 second only if solution found
    )
)
```

## Logic Table

| Config | I | L | S | T | TL | Should Stop | Reason |
|--------|---|---|---|---|----|-------------|---------|
| basic | F | F | - | F | F | No | No limits reached |
| basic | F | T | - | F | F | Yes | Iteration limit reached (regardless of solution) |
| basic | F | F | - | F | T | Yes | Time limit reached (regardless of solution) |
| basic | F | T | - | F | T | Yes | Either limit reached (regardless of solution) |
| iter_with_sol | T | F | F | F | F | No | No solution yet |
| iter_with_sol | T | T | F | F | F | No | Limit reached but no solution |
| iter_with_sol | T | T | T | F | F | Yes | Limit reached with solution |
| iter_with_sol | T | F | T | F | F | No | Solution but limit not reached |
| time_with_sol | F | F | - | T | F | No | No time limit reached |
| time_with_sol | F | T | - | T | F | Yes | Iteration limit reached (regardless) |
| time_with_sol | F | F | F | T | T | No | Time limit but no solution |
| time_with_sol | F | F | T | T | T | Yes | Time limit with solution |
| both_with_sol | T | T | T | T | F | Yes | Has solution and iteration limit reached |
| both_with_sol | T | F | T | T | T | Yes | Has solution and time limit reached |
| both_with_sol | T | T | F | T | T | No | No solution yet |
| both_with_sol | T | F | T | T | F | No | Has solution but no limits reached |
| both_with_sol | T | F | F | T | F | No | No solution and no limits reached |

## Implementation

```julia
function stop_while_loop(s::MainSolver, ::Atomic{Bool}, iter, start_time)
    # Get iteration and time limit settings
    iter_settings = get_option(s, "iteration")
    time_settings = get_option(s, "time_limit")

    # Extract variables matching logic table
    I = iter_settings[1]  # Stop on iteration only with solution
    L = iter > iter_settings[2]  # Reached iteration limit
    S = has_solution(s)  # Has solution
    T = time_settings[1]  # Stop on time only with solution
    TL = time() - start_time > time_settings[2]  # Reached time limit

    # Special case: both limits require solution
    if I && T
        # Stop if solution found and either limit reached
        if S && (L || TL)
            s.status = L ? :iteration_limit : :time_limit
            return false
        end
    else
        # Handle iteration limit
        should_stop_iteration = if I
            L && S  # Stop only if limit reached AND has solution
        else
            L      # Stop if limit reached regardless of solution
        end

        # Handle time limit
        should_stop_time = if T
            TL && S  # Stop only if limit reached AND has solution
        else
            TL      # Stop if limit reached regardless of solution
        end

        if should_stop_iteration
            s.status = :iteration_limit
            return false
        end

        if should_stop_time
            s.status = :time_limit
            return false
        end
    end

    return true
end
```

This implementation follows the logic table exactly:
- For basic config (I=F, T=F): Stops at any limit regardless of solution
- For iter_with_sol (I=T): Stops at iteration limit only with solution
- For time_with_sol (T=T): Stops at time limit only with solution
- For both_with_sol (I=T, T=T): Stops if solution found AND either limit reached
