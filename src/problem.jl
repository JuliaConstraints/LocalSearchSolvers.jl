abstract type AbstractProblem end

struct _Problem{D <: AbstractDomain,F <: Function} <: AbstractProblem
    variables::Dictionary{Int,Variable{D}}
    constraints::Dictionary{Int,_Constraint{F}}
    objectives::Dictionary{Int,_Objective{F}}

    # counter to add new variables: vars, cons, objs
    max_vars::Ref{Int} # TODO: UInt ?
    max_cons::Ref{Int}
    max_objs::Ref{Int}
end

function _Problem(D::Type, F::Type)
    variables = Dictionary{Int,Variable{D}}()
    constraints = Dictionary{Int,_Constraint{F}}()
    objectives = Dictionary{Int,_Objective{F}}()
    max_vars = Ref(zero(Int))
    max_cons = Ref(zero(Int))
    max_objs = Ref(zero(Int))

    _Problem(variables, constraints, objectives, max_vars, max_cons, max_objs)
end

struct Problem <: AbstractProblem
    variables::Dictionary{Int,Variable}
    constraints::Dictionary{Int,Constraint}
    objectives::Dictionary{Int,Objective}

    # counter to add new variables: vars, cons, objs
    max_vars::Ref{Int} # TODO: UInt ?
    max_cons::Ref{Int}
    max_objs::Ref{Int}
end

function Problem(;
    variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),
    constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),
    objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),
)
    max_vars = Ref(zero(Int))
    max_cons = Ref(zero(Int))
    max_objs = Ref(zero(Int))

    Problem(variables, constraints, objectives, max_vars, max_cons, max_objs)
end

function problem(;
    vars_types::_ValOrVect=Float64,
    func_types::_ValOrVect=Function,
    domain::Symbol=:discrete, # discrete or continuous or mixed
    discrete::Symbol=:set, # set or indices (or eventually ranges), or mixed
    continuous::Symbol=:single, # single or multiple intervals, or mixed
)
    float_union = _datatype_to_union(_filter(vars_types, AbstractFloat))
    vars_union = _datatype_to_union(vars_types)
    func_union = _datatype_to_union(func_types)

    dom_types = Vector{DataType}()
    if domain ∈ [:mixed, :discrete]
        if discrete ∈ [:mixed, :set]
            push!(dom_types, SetDomain{vars_union})
        end
        if discrete ∈ [:mixed, :indices]
            push!(dom_types, IndicesDomain{vars_union})
        end
    end
    if domain ∈ [:mixed, :continuous]
        if continuous ∈ [:mixed, :single]
            push!(dom_types, ContinuousInterval{float_union})
        end
        if continuous ∈ [:mixed, :multiple]
            push!(dom_types, ContinuousIntervals{float_union})
        end
    end
    dom_union = _datatype_to_union(dom_types)

    return _Problem(dom_union, func_union)
end

## methods

# accessors
_max_vars(p::AbstractProblem) = p.max_vars.x
_max_cons(p::AbstractProblem) = p.max_cons.x
_max_objs(p::AbstractProblem) = p.max_objs.x
_inc_vars!(p::AbstractProblem) = p.max_vars.x += 1
_inc_cons!(p::AbstractProblem) = p.max_cons.x += 1
_inc_objs!(p::AbstractProblem) = p.max_objs.x += 1

get_variables(p::AbstractProblem) = p.variables
get_constraints(p::AbstractProblem) = p.constraints
get_objectives(p::AbstractProblem) = p.objectives

get_variable(p::AbstractProblem, ind::Int) = get_variables(p)[ind]
get_constraint(p::AbstractProblem, ind::Int) = get_constraints(p)[ind]
get_objective(p::AbstractProblem, ind::Int) = get_objectives(p)[ind]
get_domain(p::AbstractProblem, ind::Int) = _get_domain(get_variable(p, ind))
get_name(p::AbstractProblem, x::Int) = _get_name(get_variable(p, x))

get_cons_from_var(p::AbstractProblem, x::Int) = _get_constraints(get_variable(p, x))
get_vars_from_cons(p::AbstractProblem, c::Int) = _get_vars(get_constraint(p, c))

length_var(p::AbstractProblem, ind::Int) = _length(get_variable(p, ind))
length_cons(p::AbstractProblem, ind::Int) = _length(get_constraint(p, ind))
length_objs(p::AbstractProblem) = length(get_objectives(p))
length_vars(p::AbstractProblem) = length(get_variables(p))

draw(p::AbstractProblem, x::Int) = _draw(get_variable(p, x))
# TODO: _get! for Indices domain
constriction(p::AbstractProblem, x::Int) = _constriction(get_variable(p, x))

delete_value!(p::AbstractProblem, x::Int, value::Int) = _delete!(get_variable(p, x), value)
delete_var_from_cons!(p::AbstractProblem, c::Int, x::Int) = _delete!(get_constraint(p, c), x)

add_value!(p::AbstractProblem, x::Int, value::Int) = _add!(get_variable(p, x), value)
add_var_to_cons!(p::AbstractProblem, c::Int, x::Int) = _add!(get_constraint(p, c), x)

# Add variable
function add!(p::AbstractProblem, x::Variable)
    _inc_vars!(p)
    insert!(get_variables(p), _max_vars(p), x)
end
function variable!(p::AbstractProblem, d::AbstractDomain)
    add!(p, variable(d, "x" * string(_max_vars(p) + 1)))
end

# Add constraint
function add!(p::AbstractProblem, c::Constraint)
    _inc_cons!(p)
    insert!(get_constraints(p), _max_cons(p), c)
    foreach(x -> _add_to_constraint!(p.variables[x], _max_cons(p)), c.vars)
end
function constraint!(p::AbstractProblem, f::Function, vars::AbstractVector{Int})
    add!(p, constraint(f, vars, p.variables))
end

# Add Objective
function add!(p::AbstractProblem, o::Objective)
    _inc_objs!(p)
    insert!(get_objectives(p), _max_objs(p), o)
end
function objective!(p::AbstractProblem, f::Function)
    add!(p, objective(f, "o" * string(_max_objs(p) + 1)))
end

# I/O

"""
    describe(p::AbstractProblem)
    describe(s::AbstractSolver)

Describe the model of either a `Problem` or a `Solver`.
"""
function describe(p::AbstractProblem) # TODO: rewrite _describe
    objectives = ""
    if length(p.objectives) == 0
        objectives = "Constraint Satisfaction Program (CSP)"
    else
        objectives = "Constraint Optimization Program (COP) with Objective(s)\n"
        objectives *=
            mapreduce(o -> "\t\t" * o.name * "\n", *, get_objectives(p); init="")[1:end - 1]
    end
    variables = mapreduce(
        x -> "\t\t" * x[2].name * "($(x[1])): " * string(x[2].domain.points) * "\n",
        *, pairs(p.variables); init=""
    )[1:end - 1]
    constraints = mapreduce(c -> "\t\tc$(c[1]): " * string(c[2].vars) * "\n", *, pairs(p.constraints); init="")[1:end - 1]

    str =
    """
    Problem description
        $objectives
        Variables: $(length(p.variables))
    $variables
        Constraints: $(length(p.constraints))
    $constraints
    """

    return str
end

# Neighbours
function _neighbours(p::AbstractProblem, x::Int)
    neighbours = Set{Int}()
    foreach(
        c -> foreach(y -> push!(neighbours, y), get_vars_from_cons(p, c)),
        get_cons_from_var(p, x)
    )
    return delete!(neighbours, x)
end

"""
    is_sat(p::Problem)
Return `true` if `p` is a satisfaction problem.
"""
is_sat(p::AbstractProblem) = length_objs(p) == 0
