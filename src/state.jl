mutable struct _State{T <: Number} # TODO: make an abstract state type
    values::Dictionary{Int,T} # TODO: handle multiple value type
    vars_costs::Dictionary{Int,Float64}
    cons_costs::Dictionary{Int,Float64}
    tabu::Dictionary{Int,Int}
end

# Accessors
_cons_costs(s::_State) = s.cons_costs
_vars_costs(s::_State) = s.vars_costs
_values(s::_State) = s.values
_tabu(s::_State) = s.tabu

_cons_cost(s::_State, c::Int) = _cons_costs(s)[c]
_var_cost(s::_State, x::Int) = _vars_costs(s)[x]
_value(s::_State, x::Int) = _values(s)[x]
_tabu(s::_State, x::Int) = _tabu(s)[x]

function _set!(state::_State{T}, x::Int, value::T) where T <: Number
    set!(_values(state), x, value)
end
