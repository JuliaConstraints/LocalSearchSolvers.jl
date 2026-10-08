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

set_value!(c, val) = c.value = val
set_values!(c, values) = c.values = values
set_sat!(c, b) = c.solution = b

compute_cost(m::_Model, config::Configuration) = compute_cost(m, get_values(config))
compute_cost!(m::_Model, config::Configuration) = set_value!(config, compute_cost(m, config))

function Configuration(m::_Model, X)
    values = draw(m)
    val = compute_costs(m, values, X)
    return _configuration(m,values,val)
end

function _configuration(m,values,val)
    sol = val ≈ 0.0
    opt = sol && !is_sat(m)
    return Configuration(sol, opt ? sense(m) * compute_objective(m, values) : val, values)
end

"Initialize with the same ephemeral input protocol used during candidate evaluation."
function _initial_configuration(m::_Model,X)
    values=draw(m)
    max_arity=maximum(c->length(c.vars),get_constraints(m);init=0)
    input=Vector{eltype(values)}(undef,max_arity)
    val=sum(c->compute_cost(c,values,X,input),get_constraints(m);init=0.0)
    return _configuration(m,values,val),input
end
