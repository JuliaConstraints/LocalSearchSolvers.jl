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

# Forwards from state field
@forward Solver.state _cons_costs, _vars_costs, _values, _tabu
@forward Solver.state _cons_cost, _var_cost, _value
@forward Solver.state _set!

## Internal to solve! function
function _draw!(s::Solver)
    foreach(x -> _set!(s, x, draw(s, x)), keys(get_variables(s)))
end

function _compute_cost!(s::Solver, ind::Int, c::Constraint)
    old_cost = _cons_cost(s, ind)
    new_cost = c.f(map(x -> value(s, x), c.vars)...)
    _cons_cost(s, ind) = new_cost
    foreach(x -> _var_cost(s, x) += new_cost - old_cost, c.vars)
end

function _compute_costs!(s::Solver; cons_lst::Set{Int}=Set{Int}())
    if isempty(cons_lst)
        foreach(((id, c),) -> _compute_cost!(s, id, c), pairs(s.problem.constraints))
    else
        foreach(
            ((id, c),) -> _compute_cost!(s, id, c),
            pairs(view(s.problem.constraints, Indices(cons_lst)))
        )
    end
end
