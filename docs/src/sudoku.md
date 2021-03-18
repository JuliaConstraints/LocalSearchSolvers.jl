# Sudoku

From Wikipedia's English page.
> Sudoku is a logic-based, combinatorial number-placement puzzle. In classic sudoku, the objective is to fill a 9×9 grid with digits so that each column, each row, and each of the nine 3×3 subgrids that compose the grid contain all of the digits from 1 to 9. The puzzle setter provides a partially completed grid, which for a well-posed puzzle has a single solution.

Each column, row, and region of the sudoku grid can only have a number from each of 1 to 9.

For instance, given this initial grid:

<img src="https://upload.wikimedia.org/wikipedia/commons/f/ff/Sudoku-by-L2G-20050714.svg" width="256" height="256">

The final state (i.e. solution) must be:

<img src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Sudoku_solution_1.svg" width="256" height="256">

## Constructing a sudoku model

```@docs
ConstraintModels.sudoku
```
## Detailed implementation

To start modeling with Sudoku with the solver,  we will use [JuMP.jl](https://github.com/jump-dev/JuMP.jl) syntax.

* First, create a model with `JuMP.Model(CBLS.Optimizer)`. Given `n = 3` the grid will be of size `n^2 by n^2` (i.e. 9×9)

 ```julia
using LocalSearchSolvers # a CBLS alias is exported
using JuMP

N = n^2
model = JuMP.Model(CBLS.Optimizer)
```

* Create a matrix of variables, where each variable represents a cell of the Sudoku, this means that every variable must be an integer between 1 and 9.
(If initial values are provided, the variables representing the known values take will be constant variables, and the rest of the unknown variables are initialized as integers between 1 and 9)

 ```julia
# Create and initialize variables.
if isnothing(start) # If no initial configuration is provided
    @variable(m, X[1:N, 1:N], DiscreteSet(1:N)) # Create a matrix of N*N variables with values from 1 to N
else
    @variable(m, X[1:N, 1:N]) # Create a matrix of N*N variables with no value taken yet
    for i in 1:N, j in 1:N # Iterate through the matrix
        v_ij = start[i,j] # Retrieve the value of the current cell
        if 1 ≤ v_ij ≤ N # If the value of the current cell is a number between 1 and N (i.e. already provided by the initial configuration)
        # Create a constraint forcing the variable representing the current cell to be a constant equal to the value provided by the initial configuration
            @constraint(m, X[i,j] in DiscreteSet(v_ij))
        else
            @constraint(m, X[i,j] in DiscreteSet(1:N)) # Else create a constraint stating that the variable must be between 1 and N
        end
    end
end
```

* Define the rows, columns and block constraints. The solver has a Global Constraint `AllDifferent()` stating that a set of variables must have different values.

 ```julia
for i in 1:N
    @constraint(m, X[i,:] in AllDifferent()) # All variables on the same row must be different
    @constraint(m, X[:,i] in AllDifferent()) # All variables on the same column must be different
end
for i in 0:(n-1), j in 0:(n-1)
    @constraint(m, vec(X[(i*n+1):(n*(i+1)), (j*n+1):(n*(j+1))]) in AllDifferent()) # All variables on the same block must be different
end
 ```

* Finally, solve model using the `optimize!()` function with the model in arguments *
 ```julia
# Run the solver
optimize!(m)
```

After model is solved, use `value.(grid)` to get the final value of all variables on the grid
matrix, and display the solution using the `display()` function

```julia
# Retrieve and display the values
solution = value.(grid)
display(solution, Val(:sudoku))
```

