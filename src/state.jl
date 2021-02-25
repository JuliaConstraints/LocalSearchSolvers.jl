abstract type AbstractState end

struct EmptyState <: AbstractState end

"""
    GeneralState{T <: Number}
A mutable structure to store the general state of a solver. All methods applied to `GeneralState` are forwarded to `S <: AbstractSolver`.
```
mutable struct GeneralState{T <: Number} <: AbstractState
    configuration::Configuration{T}
    cons_costs::Dictionary{Int, Float64}
    last_improvement::Int
    tabu::Dictionary{Int, Int}
    vars_costs::Dictionary{Int, Float64}
end
```
"""
mutable struct _State{T} <: AbstractState
    configuration::Configuration{T}
    cons_costs::Dictionary{Int, Float64}
    optimizing::Bool
    last_improvement::Int
    vars_costs::Dictionary{Int, Float64}
end

@forward _State.configuration get_values, get_error, get_value, compute_cost!, set_values!
@forward _State.configuration set_value!, set_sat!

const State = Union{EmptyState, _State}

state() = EmptyState()
function state(m::_Model, pool = pool(); opt = false)
    lc, lv = length_cons(m) > 0, length_vars(m) > 0
    config = Configuration(m)
    cons = lc ? zeros(Float64, get_constraints(m)) : Dictionary{Int,Float64}()
    last_improvement = 0
    vars = lv ? zeros(Float64, get_variables(m)) : Dictionary{Int,Float64}()
    return _State(config, cons, opt, last_improvement, vars)
end

"""
    _cons_costs(s::S) where S <: Union{_State, AbstractSolver}
Access the constraints costs.
"""
_cons_costs(s::_State) = s.cons_costs

"""
    _vars_costs(s::S) where S <: Union{_State, AbstractSolver}
Access the variables costs.
"""
_vars_costs(s::_State) = s.vars_costs

"""
    _vars_costs(s::S) where S <: Union{_State, AbstractSolver}
Access the variables costs.
"""
_values(s::_State) = get_values(s)

"""
    _optimizing(s::S) where S <: Union{_State, AbstractSolver}
Check if `s` is in an optimizing state.
"""
_optimizing(s::_State) = s.optimizing

"""
    _cons_costs!(s::S, costs) where S <: Union{_State, AbstractSolver}
Set the constraints costs.
"""
_cons_costs!(s::_State, costs) = s.cons_costs = costs

"""
    _vars_costs!(s::S, costs) where S <: Union{_State, AbstractSolver}
Set the variables costs.
"""
_vars_costs!(s::_State, costs) = s.vars_costs = costs

"""
    _values!(s::S, values) where S <: Union{_State, AbstractSolver}
Set the variables values.
"""
_values!(s::_State{T}, values) where T <: Number = set_values!(s, values)

"""
    _optimizing!(s::S) where S <: Union{_State, AbstractSolver}
Set the solver `optimizing` status to `true`.
"""
_optimizing!(s::_State) = s.optimizing = true

"""
    _satisfying!(s::S) where S <: Union{_State, AbstractSolver}
Set the solver `optimizing` status to `false`.
"""
_satisfying!(s::_State) = s.optimizing = false

"""
    _cons_cost(s::S, c) where S <: Union{_State, AbstractSolver}
Return the cost of constraint `c`.
"""
_cons_cost(s::_State, c) = get!(_cons_costs(s), c, 0.0)

"""
    _var_cost(s::S, x) where S <: Union{_State, AbstractSolver}
Return the cost of variable `x`.
"""
_var_cost(s::_State, x) = get!(_vars_costs(s), x, 0.0)

"""
    _value(s::S, x) where S <: Union{_State, AbstractSolver}
Return the value of variable `x`.
"""
_value(s::_State, x) = _values(s)[x]

"""
    _cons_cost!(s::S, c, cost) where S <: Union{_State, AbstractSolver}
Set the `cost` of constraint `c`.
"""
_cons_cost!(s::_State, c, cost) = _cons_costs(s)[c] = cost

"""
    _var_cost!(s::S, x, cost) where S <: Union{_State, AbstractSolver}
Set the `cost` of variable `x`.
"""
_var_cost!(s::_State, x, cost) = _vars_costs(s)[x] = cost

"""
    _value!(s::S, x, val) where S <: Union{_State, AbstractSolver}
Set the value of variable `x` to `val`.
"""
_value!(s::_State, x, val) = _values(s)[x] = val

"""
    _set!(s::S, x, val) where S <: Union{_State, AbstractSolver}
Set the value of variable `x` to `val`.
"""
_set!(s::_State, x, val) = set!(_values(s), x, val)

"""
    _set!(s::S, x, y) where S <: Union{_State, AbstractSolver}
Swap the values of variables `x` and `y`.
"""
function _swap_value!(s::_State, x, y)
    aux = _value(s, x)
    _value!(s, x, _value(s, y))
    _value!(s, y, aux)
end

_last_improvement(s::_State) = s.last_improvement
_inc_last_improvement!(s::_State) = s.last_improvement += 1
_reset_last_improvement!(s::_State) = s.last_improvement = 0

has_solution(s::_State) = is_solution(s.configuration)

function set_error!(s::_State, err)
    sat = err ≈ 0.0
    set_sat!(s, sat)
    !sat && set_value!(s, err)
end

get_error(::EmptyState) = Inf