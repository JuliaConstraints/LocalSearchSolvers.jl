mutable struct Configuration{T}
    solution::Bool
    value::Float64
    values::Dictionary{Int, T}
end

is_solution(c) = c.solution
value(c) = c.value
error(c) = is_solution(c) ? 0.0 : value(c)
values(c) = c.values
value(c, x) = values(c)[x] 

compute_cost(m, config::Configuration) = compute_cost(m, values(config))

is_empty(::Configuration) = false
best_config(config::Configuration) = config

function Configuration(m::_Model)
    values = draw(m)
    val = compute_cost(m, values)
    sol = val ≈ 0.0
    opt = sol && !is_sat(m)
    return Configuration(sol, opt ? compute_objective(m, values) : val, values)
end