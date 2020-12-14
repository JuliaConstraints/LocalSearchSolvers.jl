mutable struct _State{T <: Number} # TODO: make an abstract state type
    values::Dictionary{Int,T} # TODO: handle multiple value type
    vars_costs::Dictionary{Int,Float64}
    cons_costs::Dictionary{Int,Float64}
    error::Float64
    tabu::Dictionary{Int,Int}
    optimizing::Bool
    best_solution::Dictionary{Int,T}
    best_solution_value::Union{Nothing,T}
end

# Accessors
_cons_costs(s::_State) = s.cons_costs
_vars_costs(s::_State) = s.vars_costs
_values(s::_State) = s.values
_tabu(s::_State) = s.tabu
_optimizing(s::_State) = s.optimizing
_best(s::_State) = s.best_solution_value

_cons_costs!(s::_State, costs::Dictionary{Int,Float64}) = s.cons_costs = costs
_vars_costs!(s::_State, costs::Dictionary{Int,Float64}) = s.vars_costs = costs
_values!(s::_State{T}, values::Dictionary{Int,T}) where T <: Number = s.values = values
_tabu!(s::_State, tabu::Dictionary{Int,Int}) = s.tabu = tabu
_optimizing!(s::_State) = s.optimizing = true
_satisfying!(s::_State) = s.optimizing = false
_switch!(s::_State) = _optimizing(s) ? _satisfying!(s) : _optimizing!(s)

_cons_cost(s::_State, c::Int) = _cons_costs(s)[c]
_var_cost(s::_State, x::Int) = _vars_costs(s)[x]
_value(s::_State, x::Int) = _values(s)[x]
_tabu(s::_State, x::Int) = _tabu(s)[x]

_cons_cost!(s::_State, c::Int, cost::Float64) = _cons_costs(s)[c] = cost
_var_cost!(s::_State, x::Int, cost::Float64) = _vars_costs(s)[x] = cost
_value!(s::_State{T}, x::Int, val::T) where T <: Number = _values(s)[x] = val
_decrease_tabu!(s::_State, x::Int) = _tabu(s)[x] -= 1
_delete_tabu!(s::_State, x::Int) = delete!(_tabu(s), x)
_empty_tabu!(s::_State) = empty!(_tabu(s))
_length_tabu(s::_State) = length(_tabu(s))

function _best!(s::_State{T}, val::T) where {T <: Number}
    if isnothing(_best(s)) || val < _best(s)
        s.best_solution_value = val
        s.best_solution = s.values
    end
end

_error!(s::_State, val::T) where {T <: Number} = s.error = val
_error(s::_State) = s.error
_up_error!(s::_State, old_v::T, v::T) where {T <: Number} = s.error += v - old_v

function _insert_tabu!(s::_State, x::Int, tabu_time::Int)
    insert!(_tabu(s), x, max(1, tabu_time))
end

function _decay_tabu!(s::_State)
    foreach(
        ((x, tabu),) -> tabu == 1 ? _delete_tabu!(s, x) : _decrease_tabu!(s, x),
        pairs(_tabu(s))
    )
end

function _set!(s::_State{T}, x::Int, value::T) where T <: Number
    set!(_values(s), x, value)
end

function _swap_value!(s::_State, x::Int, y::Int)
    aux = _value(s, x)
    _value!(s, x, _value(s, y))
    _value!(s, y, aux)
end

function _select_worse(s::_State)
    nontabu = setdiff(keys(_vars_costs(s)), keys(_tabu(s)))
    return _find_rand_argmax(view(_vars_costs(s), nontabu))
end
