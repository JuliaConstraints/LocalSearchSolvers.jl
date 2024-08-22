"""
    struct Configuration{T}

A configuration is an instance of a model with a set of values. It can either be a (satisfying) solution or not.

# Fields
- `solution::Bool`: Whether the configuration is a solution.
- `value::Float64`: The cost of the configuration.
- `values::Dictionary{Int, T}`: The values taken by the variables in the configuration.
"""
mutable struct Configuration{T}
    solution::Bool
    value::Float64
    values::Dictionary{Int, T}
end

"""
    is_solution(config::Configuration)

Check if a configuration is a (satisfying) solution.
"""
is_solution(c) = c.solution

"""
    get_value(config::Configuration)

Get the value (cost) of a configuration. To get the error please use `get_error`.
"""
get_value(c) = c.value

"""
    get_error(config::Configuration)

Get the error of a configuration.
"""
get_error(c) = is_solution(c) ? 0.0 : get_value(c)

"""
    get_values(config::Configuration)

Get the values of a configuration.
"""
get_values(c) = c.values

"""
    get_value(config::Configuration, x::Int)

Get the value of a variable of id `x` in a configuration.
"""
get_value(c, x) = get_values(c)[x]

"""
    set_value!(config::Configuration, val::Float64)

Set the value of a configuration.
"""
set_value!(c, val) = c.value = val

"""
    set_values!(config::Configuration, values::Dictionary{Int, T})

Set the values of a configuration.
"""
set_values!(c, values) = c.values = values

"""
    set_sat!(config::Configuration, b::Bool)

Set the satisfaction status of a configuration.
"""
set_sat!(c, b) = c.solution = b

"""
    compute_cost(m::Model, config::Configuration)

Compute the cost of a configuration.
"""
compute_cost(m, config::Configuration) = compute_cost(m, get_values(config))

"""
    compute_cost!(m::Model, config::Configuration)

Compute the cost of a configuration and set it.
"""
compute_cost!(m, config::Configuration) = set_value!(config, compute_cost(m, config))

"""
    Configuration(m::Model, X)

Create a configuration from a model and a set of values.
"""
function Configuration(m::Model, X)
    values = draw(m)
    val = compute_costs(m, values, X)
    sol = val ≈ 0.0
    opt = sol && !is_sat(m)
    return Configuration(sol, opt ? compute_objective(m, values) : val, values)
end

@testitem "Configuration" tags=[:configuration, :state] begin
    import LocalSearchSolvers: Configuration, is_solution, get_value, get_values, get_value
    import LocalSearchSolvers: set_value!, set_values!, set_sat!, compute_cost
    import LocalSearchSolvers: compute_cost!, get_error

    import Dictionaries: Dictionary

    m = model()
    X = [1, 2, 3]
    c = Configuration(m, X)
    @test is_solution(c)
    @test get_value(c) == compute_cost(m, c)
    @test get_values(c) == X
    @test get_value(c, 1) == 1
    @test get_value(c, 2) == 2
    @test get_value(c, 3) == 3
    set_value!(c, 0.0)
    @test get_value(c) == 0.0
    set_values!(c, Dictionary(1:3, [3, 2, 1]))
    @test get_values(c) == [3, 2, 1]
    set_sat!(c, false)
    @test !is_solution(c)
    @test get_error(c) == get_value(c)
    @test compute_cost(m, c) == get_value(c)
    @test compute_cost!(m, c) == get_value(c)
end
