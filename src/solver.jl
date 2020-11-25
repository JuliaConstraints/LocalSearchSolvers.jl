mutable struct _State{T <: Number}
    values::Dictionary{Int,T}
    vars_costs::Dictionary{Int,Float64}
    cons_costs::Dictionary{Int,Float64}
    tabu::Dictionary{Int,Int}
end

struct Solver{T <: Number}
    problem::Problem
    state::_State{T}
end