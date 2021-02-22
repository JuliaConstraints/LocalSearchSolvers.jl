mutable struct Configuration{T}
    solution::Bool
    value::Float64
    values::Dictionary{Int, T}
end

is_solution(c) = c.solution
is_empty(::Configuration) = false

get_value(c) = c.value
get_error(c) = is_solution(c) ? 0.0 : get_value(c)
get_values(c) = c.values
get_value(c, x) = get_values(c)[x] 

set_value!(c, val) = c.value = val
set_value!(c, x, val) = get_values(c)[x] = val
set_values!(c, values) = c.values = values
set_sat!(c, b) = c.solution = b

compute_cost(m, config::Configuration) = compute_cost(m, get_values(config))
compute_cost!(m, config::Configuration) = set_value!(config, compute_cost(m, config))

# best_config(config::Configuration) = config # TODO: what is that?

function empty!(c::Configuration)
    c.solution = false
    c.value = Inf
    empty!(c.values)
end

function Configuration(m::_Model)
    values = draw(m)
    val = compute_costs(m, values)
    sol = val ≈ 0.0
    opt = sol && !is_sat(m)
    return Configuration(sol, opt ? compute_objective(m, values) : val, values)
end