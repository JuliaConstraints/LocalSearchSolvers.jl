struct Problem
    variables::Dictionary{Int,Variable}
    constraints::Dictionary{Int,Constraint}
    objectives::Dictionary{Int,Objective} 

    # counter to add new variables: vars, cons, objs
    max_vars::Ref{Int} # TODO: UInt ?
    max_cons::Ref{Int}
    max_objs::Ref{Int}
end

function Problem(;
    variables::Dictionary{Int,Variable} = Dictionary{Int,Variable}(),
    constraints::Dictionary{Int,Constraint} = Dictionary{Int,Constraint}(),
    objectives::Dictionary{Int,Objective} = Dictionary{Int,Objective}(),
)
    max_vars = Ref(zero(Int))
    max_cons = Ref(zero(Int))
    max_objs = Ref(zero(Int))

    Problem(variables, constraints, objectives, max_vars, max_cons, max_objs)
end

## methods

# accessors
_max_vars(p::Problem) = p.max_vars.x
_max_cons(p::Problem) = p.max_cons.x
_max_objs(p::Problem) = p.max_objs.x
_inc_vars!(p::Problem) = p.max_vars.x += 1
_inc_cons!(p::Problem) = p.max_cons.x += 1
_inc_objs!(p::Problem) = p.max_objs.x += 1

_variables(p::Problem) = p.variables
_constraints(p::Problem) = p.constraints
_objectives(p::Problem) = p.objectives

_variable(p::Problem, ind::Int) = _variables(p)[ind]
_constraint(p::Problem, ind::Int) = _constraints(p)[ind]
_objective(p::Problem, ind::Int) = _objectives(p)[ind]

_length(p::Problem, ind::Int, type = Val(:var)) = _length(type, p::Problem, ind::Int)
_length(::Val{:var}, p::Problem, ind::Int) = _length(_variable(p, ind))
_length(::Val{:obj}, p::Problem, ind::Int) = _length(_constraint(p, ind))

_draw(p::Problem, x::Int) = _draw(_variable(p, x))
# TODO: _get! for Indices domain
_constriction(p::Problem, x::Int) = _constriction(_variable(p, x))

function _delete!(p::Problem, x::Int, value::Int, type = Val(:var))
    _delete!(type, p::Problem, x::Int, value::Int)
end
_delete!(::Val{:var}, p::Problem, x::Int, value::Int) = _delete!(_variable(p, x), value)
_delete!(::Val{:obj}, p::Problem, c::Int, x::Int) = _delete!(_objective(p, c), x)

function _add!(p::Problem, x::Int, value::Int, type = Val(:var))
    _add!(type, p::Problem, x::Int, value::Int)
end
_add!(::Val{:var}, p::Problem, x::Int, value::Int) = _add!(_variable(p, x), value)
_add!(::Val{:obj}, p::Problem, c::Int, x::Int) = _add!(_objective(p, c), x)

# Add variable
function add!(p::Problem, x::Variable)
    insert!(p.variables, _max_vars(p), x)
    _inc_vars(p)
end
function add!(p::Problem, d::D) where D <: AbstractDomain
    variable(d, "x_" * string(_max_vars(p)))
    add!(p,x)
end

# Add constraint
function add!(p::Problem, c::Constraint)
    insert!(p.constraints, _max_cons(p), c)
    foreach(x -> _add_to_constraint!(p.variables[x], _max_cons(p)), c.vars)
    _inc_cons(p)
end
function add!(p::Problem, f::F, vars::Vector{Int}) where {F <: Function}
    add!(p, constraint(f, vars, p.variables))
end

# Add Objective
function add!(p::Problem, o::Objective)
    insert!(p.objectives, _max_objs(p), o)
    _inc_cons!(p)
end
function add!(p::Problem, f::F) where {F <: Function}    
    add!(p, objective(f, "c_" * string(_max_objs(p))))
end