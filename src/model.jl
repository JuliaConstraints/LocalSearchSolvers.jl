struct Model{V <: Variable{<:AbstractDomain},C <: Constraint{<:Function},O <: Objective{<:Function}}
    variables::Dictionary{Int,V}
    constraints::Dictionary{Int,C}
    objectives::Dictionary{Int,O}

    # counter to add new variables: vars, cons, objs
    max_vars::Ref{Int} # TODO: UInt ?
    max_cons::Ref{Int}
    max_objs::Ref{Int}

    # Bool to indicate if the Model instance has been specialized (relatively to types)
    specialized::Ref{Bool}
    
    # Symbol to indicate the kind of model for specialized methods such as pretty printing
    kind::Symbol
end

function Model(;
    vars=Dictionary{Int,Variable}(),
    cons=Dictionary{Int,Constraint}(),
    objs=Dictionary{Int,Objective}(),    
    kind = :generic,
)

    max_vars = Ref(zero(Int))
    max_cons = Ref(zero(Int))
    max_objs = Ref(zero(Int))

    specialized = Ref(false)

    Model(vars, cons, objs, max_vars, max_cons, max_objs, specialized, kind)
end

## methods
# accessors
_max_vars(m::Model) = m.max_vars.x
_max_cons(m::Model) = m.max_cons.x
_max_objs(m::Model) = m.max_objs.x
_inc_vars!(m::Model) = m.max_vars.x += 1
_inc_cons!(m::Model) = m.max_cons.x += 1
_inc_objs!(m::Model) = m.max_objs.x += 1

get_variables(m::Model) = m.variables
get_constraints(m::Model) = m.constraints
get_objectives(m::Model) = m.objectives
get_kind(m::Model) = m.kind

get_variable(m::Model, ind::Int) = get_variables(m)[ind]
get_constraint(m::Model, ind::Int) = get_constraints(m)[ind]
get_objective(m::Model, ind::Int) = get_objectives(m)[ind]
get_domain(m::Model, ind::Int) = _get_domain(get_variable(m, ind))
get_name(m::Model, x::Int) = _get_name(get_variable(m, x))

get_cons_from_var(m::Model, x::Int) = _get_constraints(get_variable(m, x))
get_vars_from_cons(m::Model, c::Int) = _get_vars(get_constraint(m, c))

length_var(m::Model, ind::Int) = _length(get_variable(m, ind))
length_cons(m::Model, ind::Int) = _length(get_constraint(m, ind))
length_objs(m::Model) = length(get_objectives(m))
length_vars(m::Model) = length(get_variables(m))

draw(m::Model, x::Int) = _draw(get_variable(m, x))
# TODO: _get! for Indices domain
constriction(m::Model, x::Int) = _constriction(get_variable(m, x))

delete_value!(m::Model, x::Int, value::Int) = _delete!(get_variable(m, x), value)
delete_var_from_cons!(m::Model, c::Int, x::Int) = _delete!(get_constraint(m, c), x)

add_value!(m::Model, x::Int, value::Int) = _add!(get_variable(m, x), value)
add_var_to_cons!(m::Model, c::Int, x::Int) = _add!(get_constraint(m, c), x)

# Add variable
function add!(m::Model, x::Variable)
    _inc_vars!(m)
    insert!(get_variables(m), _max_vars(m), x)
end
function variable!(m::Model, d::AbstractDomain)
    add!(m, variable(d, "x" * string(_max_vars(m) + 1)))
end

# Add constraint
function add!(m::Model, c::Constraint)
    _inc_cons!(m)
    insert!(get_constraints(m), _max_cons(m), c)
    foreach(x -> _add_to_constraint!(m.variables[x], _max_cons(m)), c.vars)
end
function constraint!(m::Model, f::F, vars::AbstractVector{Int}) where F <: Function
    add!(m, constraint(f, vars, m.variables))
end

# Add Objective
function add!(m::Model, o::Objective)
    _inc_objs!(m)
    insert!(get_objectives(m), _max_objs(m), o)
end
function objective!(m::Model, f::Function)
    add!(m, objective(f, "o" * string(_max_objs(m) + 1)))
end

# I/O

"""
    describe(m::Model)
    describe(s::AbstractSolver)

Describe the model of either a `Model` or a `Solver`.
"""
function describe(m::Model) # TODO: rewrite _describe
    objectives = ""
    if length(m.objectives) == 0
        objectives = "Constraint Satisfaction Program (CSP)"
    else
        objectives = "Constraint Optimization Program (COP) with Objective(s)\n"
        objectives *=
            mapreduce(o -> "\t\t" * o.name * "\n", *, get_objectives(m); init="")[1:end - 1]
    end
    variables = mapreduce(
        x -> "\t\t" * x[2].name * "($(x[1])): " * string(x[2].domain.points) * "\n",
        *, pairs(m.variables); init=""
    )[1:end - 1]
    constraints = mapreduce(c -> "\t\tc$(c[1]): " * string(c[2].vars) * "\n", *, pairs(m.constraints); init="")[1:end - 1]

    str =
    """
    Model description
        $objectives
        Variables: $(length(m.variables))
    $variables
        Constraints: $(length(m.constraints))
    $constraints
    """

    return str
end

# Neighbours
function _neighbours(m::Model, x::Int, dim::Int = 0)
    if dim == 0
        return get_domain(m, x)
    else
        neighbours = Set{Int}()
        foreach(
            c -> foreach(y -> push!(neighbours, y), get_vars_from_cons(m, c)),
            get_cons_from_var(m, x)
        )
        return delete!(neighbours, x)
    end
end

"""
    is_sat(m::Model)
Return `true` if `p` is a satisfaction model.
"""
is_sat(m::Model) = length_objs(m) == 0

"""
    is_specialized(m::Model)
    is_specialized(s::Solver)
Return `true` if the model is already specialized.
"""
function is_specialized(m::Model)
    return m.specialized.x
end

"""
    specialize(m::Model)
    specialize(s::Solver)
Specialize the structure of a model to avoid dynamic type attribution at runtime.
"""
function specialize(m::Model)
    vars_types = Set{Type}()
    cons_types = Set{Type}()
    objs_types = Set{Type}()

    foreach(x -> push!(vars_types, typeof(x.domain)), get_variables(m))
    foreach(c -> push!(cons_types, typeof(c.f)), get_constraints(m))
    foreach(o -> push!(objs_types, typeof(o.f)), get_objectives(m))

    vars_union = _datatype_to_union(vars_types)
    cons_union = _datatype_to_union(cons_types)
    objs_union = _datatype_to_union(objs_types)

    vars = similar(get_variables(m), Variable{vars_union})
    cons = similar(get_constraints(m), Constraint{cons_union})
    objs = similar(get_objectives(m), Objective{objs_union})

    foreach(x -> vars[x] = get_variable(m, x), keys(vars))
    foreach(c -> cons[c] = Constraint(cons_union, get_constraint(m, c)), keys(cons))
    foreach(o -> objs[o] = Objective(objs_union, get_objective(m, o)), keys(objs))

    max_vars = Ref(_max_vars(m))
    max_cons = Ref(_max_cons(m))
    max_objs = Ref(_max_objs(m))

    specialized = Ref(true)

    Model(vars, cons, objs, max_vars, max_cons, max_objs, specialized, get_kind(m))
end
