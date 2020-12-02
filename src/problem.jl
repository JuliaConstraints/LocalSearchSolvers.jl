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
    var_types::Vector{DataType} = [Float64],
    values_type::DataType = Float64,
    domain::Symbol = :mixed, # discrete or continuous
    discrete::Symbol = :set, # set or indices (or eventually ranges), or mixed
    continuous::Symbol = :single, # single or multiple intervals, or mixed
)
    var_type = Union{values_types...}

    domain_types = Vector{DataType}()
    if domain ∈ [:mixed, :discrete]
        if discrete ∈ [:mixed, :set]
            push!(domain_types, SetDomain)
        end
        if discrete ∈ [:mixed, :indices]
            push!(domain_types, IndicesDomain)
        end
    end
    if domain == :mixed || domain == :continuous
        push!(domain_types, ContinuousInterval, ContinuousIntervals)
    end
    dom_type = Union{domain_types...}

    return var_type, dom_type
end

## methods

# accessors
_max_vars(p::Problem) = p.max_vars.x
_max_cons(p::Problem) = p.max_cons.x
_max_objs(p::Problem) = p.max_objs.x
_inc_vars!(p::Problem) = p.max_vars.x += 1
_inc_cons!(p::Problem) = p.max_cons.x += 1
_inc_objs!(p::Problem) = p.max_objs.x += 1

get_variables(p::Problem) = p.variables
get_constraints(p::Problem) = p.constraints
get_objectives(p::Problem) = p.objectives

get_variable(p::Problem, ind::Int) = get_variables(p)[ind]
get_constraint(p::Problem, ind::Int) = get_constraints(p)[ind]
get_objective(p::Problem, ind::Int) = get_objectives(p)[ind]
get_domain(p::Problem, ind::Int) = _get_domain(get_variable(p, ind))
get_name(p::Problem, x::Int) = _get_name(get_variable(p, x))

get_cons_from_var(p::Problem, x::Int) = _get_constraints(get_variable(p, x))
get_vars_from_cons(p::Problem, c::Int) = _get_vars(get_constraint(p, c))

length_var(p::Problem, ind::Int) = _length(get_variable(p, ind))
length_cons(p::Problem, ind::Int) = _length(get_constraint(p, ind))
length_objs(p::Problem) = length(get_objectives(p))
length_vars(p::Problem) = length(get_variables(p))

draw(p::Problem, x::Int) = _draw(get_variable(p, x))
# TODO: _get! for Indices domain
constriction(p::Problem, x::Int) = _constriction(get_variable(p, x))

delete_value!(p::Problem, x::Int, value::Int) = _delete!(get_variable(p, x), value)
delete_var_from_cons!(p::Problem, c::Int, x::Int) = _delete!(get_constraint(p, c), x)

add_value!(p::Problem, x::Int, value::Int) = _add!(get_variable(p, x), value)
add_var_to_cons!(p::Problem, c::Int, x::Int) = _add!(get_constraint(p, c), x)

# Add variable
function add!(p::Problem, x::Variable)
    _inc_vars!(p)
    insert!(get_variables(p), _max_vars(p), x)
end
function variable!(p::Problem, d::D) where D <: AbstractDomain
    add!(p, variable(d, "x" * string(_max_vars(p) + 1)))
end

# Add constraint
function add!(p::Problem, c::Constraint)
    _inc_cons!(p)
    insert!(get_constraints(p), _max_cons(p), c)
    foreach(x -> _add_to_constraint!(p.variables[x], _max_cons(p)), c.vars)
end
function constraint!(p::Problem, f::F, vars::Vector{Int}) where {F <: Function}
    add!(p, constraint(f, vars, p.variables))
end

# Add Objective
function add!(p::Problem, o::Objective)
    _inc_objs!(p)
    insert!(get_objectives(p), _max_objs(p), o)
end
function objective!(p::Problem, f::F) where {F <: Function}
    add!(p, objective(f, "o" * string(_max_objs(p) + 1)))
end

# I/O

"""
    describe(p::Problem)
    describe(s::Solver)

Describe the model of either a `Problem` or a `Solver`.
"""
function describe(p::Problem) # TODO: rewrite _describe
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
function _neighbours(p::Problem, x::Int)
    neighbours = Set{Int}()
    foreach(
        c -> foreach(y -> push!(neighbours, y), get_vars_from_cons(p, c)),
        get_cons_from_var(p, x)
    )
    return delete!(neighbours, x)
end

# is the problem a Satisfaction one
is_sat(p::Problem) = length_objs(p) == 0
