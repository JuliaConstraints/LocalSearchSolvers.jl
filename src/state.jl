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
mutable struct _State{T}
    configuration::Configuration{T}
    cons_costs::Dictionary{Int, Float64}
    optimizing::Bool
    last_improvement::Int
    tabu::Dictionary{Int,Int}
    vars_costs::Dictionary{Int, Float64}
end

@forward _State.configuration get_values, get_error, get_value, compute_cost!, set_values!
@forward _State.configuration set_value!, set_sat!

const State = Union{Nothing, _State}

state() = nothing
function state(m::_Model, pool = pool(); opt = false)
    lc, lv = length_cons(m) > 0, length_vars(m) > 0
    # config = is_empty(pool) ? Configuration(m) : best_config(pool)
    config = Configuration(m)
    cons = lc ? zeros(Float64, get_constraints(m)) : Dictionary{Int,Float64}()
    last_improvement = 0
    tabu = Dictionary{Int,Int}()
    vars = lv ? zeros(Float64, get_variables(m)) : Dictionary{Int,Float64}()
    return _State(config, cons, opt, last_improvement, tabu, vars)
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
    _tabu(s::S) where S <: Union{_State, AbstractSolver}
Access the list of tabu variables.
"""
_tabu(s::_State) = s.tabu

"""
    _optimizing(s::S) where S <: Union{_State, AbstractSolver}
Check if `s` is in an optimizing state.
"""
_optimizing(s::_State) = s.optimizing

"""
    _best(s::S) where S <: Union{_State, AbstractSolver}
Access the best known solution value (defined for optimization models only).
"""
_best(s::_State) = s.best_solution_value

"""
    _solution(s::S) where S <: Union{_State, AbstractSolver}
Access the best known solution.
"""
_solution(s::_State) = s.best_solution

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
    _tabu!(s::S, tabu) where S <: Union{_State, AbstractSolver}
Set the variables tabu list.
"""
_tabu!(s::_State, tabu) = s.tabu = tabu

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
    _tabu(s::S, x) where S <: Union{_State, AbstractSolver}
Return the tabu value of variable `x`.
"""
_tabu(s::_State, x) = _tabu(s)[x]

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
    _decrease_tabu!(s::S, x) where S <: Union{_State, AbstractSolver}
Decrement the tabu value of variable `x`.
"""
_decrease_tabu!(s::_State, x) = _tabu(s)[x] -= 1

"""
    _delete_tabu!(s::S, x) where S <: Union{_State, AbstractSolver}
Delete the tabu entry of variable `x`.
"""
_delete_tabu!(s::_State, x) = delete!(_tabu(s), x)

"""
    _empty_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Empty the tabu list.
"""
_empty_tabu!(s::_State) = empty!(_tabu(s))

"""
    _length_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Return the length of the tabu list.
"""
_length_tabu(s::_State) = length(_tabu(s))

"""
    _solution!(s::S, values) where S <: Union{_State, AbstractSolver}
Set the best known solution to `values`.
"""
_solution!(s::_State, values) = s.best_solution = copy(values)

"""
    _best!(s::S, val, values = Dictionary()) where S <: Union{_State, AbstractSolver}
Set the best known value to `val` and, if `values` not empty, the best known solution.
"""
function _best!(s::_State, val::Union{Nothing,T}, values=nothing) where {T <: Number}
    if isnothing(_best(s)) || val < _best(s)
        s.best_solution_value = val
        s.best_solution = copy(isnothing(values) ? s.values : values)
    end
end

# """
#     _error(s::S) where S <: Union{_State, AbstractSolver}
# Access the error of the current state of `s`.
# """
# get_error(s::_State) = get_error(s)

# """
#     _error!(s::S, val) where S <: Union{_State, AbstractSolver}
# Set the error of the current state of `s` to `val`.
# """
# set_error!(s::_State, val) = set_error!(s.config) = val

"""
    _insert_tabu!(s::S, x, tabu_time) where S <: Union{_State, AbstractSolver}
Insert the bariable `x` as tabu for `tabu_time`.
"""
_insert_tabu!(s::_State, x, tabu_time) = insert!(_tabu(s), x, max(1, tabu_time))

"""
    _decay_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Decay the tabu list.
"""
function _decay_tabu!(s::_State)
    foreach(
        ((x, tabu),) -> tabu == 1 ? _delete_tabu!(s, x) : _decrease_tabu!(s, x),
        pairs(_tabu(s))
    )
end

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

"""
    _select_worse(s::S) where S <: Union{_State, AbstractSolver}
Within the non-tabu variables, select the one with the worse error .
"""
function _select_worse(s::_State)
    nontabu = setdiff(keys(_vars_costs(s)), keys(_tabu(s)))
    return _find_rand_argmax(view(_vars_costs(s), nontabu))
end

_last_improvement(s::_State) = s.last_improvement
_inc_last_improvement!(s::_State) = s.last_improvement += 1
_reset_last_improvement!(s::_State) = s.last_improvement = 0

"""
    empty!(s::_State)

DOCSTRING
"""
function empty!(s::_State)
    s.configuration = nothing
    empty!(s.cons_costs)
    _reset_last_improvement!(s)
    empty!(s.tabu)
    empty!(s.vars_costs)
end

has_solution(::Nothing) = false
has_solution(s::_State) = is_solution(s.configuration)

function set_error!(s::_State, err)
    sat = err ≈ 0.0
    set_sat!(s, sat)
    !sat && set_value!(s, err)
end