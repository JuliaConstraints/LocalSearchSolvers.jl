mutable struct _State{T <: Number} # TODO: make an abstract state type
    values::Dictionary{Int,T} # TODO: handle multiple value type
    vars_costs::Dictionary{Int,Float64}
    cons_costs::Dictionary{Int,Float64}
    tabu::Dictionary{Int,Int}
end

struct Solver{T <: Number}
    problem::Problem
    state::_State{T}
end

function Solver{T}(p::Problem; values::Dictionary{Int,T}=Dictionary{Int,T}()
) where T <: Number
    vars, cons = zeros(Float64, get_variables(p)), zeros(Float64, get_constraints(p))
    state = _State(values, vars, cons, Dictionary{Int,Int}())
    Solver{T}(p, state)
end

function Solver{T}(;
    variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),
    constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),
    objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),
    values::Dictionary{Int,T}=Dictionary{Int,T}(),
) where T <: Number
    p = Problem(; variables=variables, constraints=constraints, objectives=objectives)
    Solver{T}(p; values=values)
end

# Forwards from problem field
@forward Solver.problem get_constraints, get_objectives, get_variables
@forward Solver.problem get_constraint, get_objective, get_variable
@forward Solver.problem add!, add_value!, add_var_to_cons!
@forward Solver.problem delete_value!, delete_var_from_cons!
@forward Solver.problem length_var, length_cons, draw, constriction, describe
@forward Solver.problem constraint!, objective!, variable!