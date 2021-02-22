mutable struct Configuration{T}
    solution::Bool
    value::Float64
    values::Dictionary{Int, T}
end

is_solution(c) = c.solution
get_value(c) = c.value
get_error(c) = is_solution(c) ? 0.0 : get_value(c)
get_values(c) = c.values
get_value(c, x) = get_values(c)[x] 

compute_cost(m, config::Configuration) = compute_cost(m, get_values(config))

is_empty(::Configuration) = false
best_config(config::Configuration) = config # TODO: what is that?

function empty!(c::Configuration)
    c.solution = false
    c.value = Inf
    empty!(c.values)
end

function Configuration(m::_Model)
    values = draw(m)
    val = compute_cost(m, values)
    sol = val ≈ 0.0
    opt = sol && !is_sat(m)
    return Configuration(sol, opt ? compute_objective(m, values) : val, values)
end