"""
    _Model{V <: Variable{<:AbstractDomain},C <: Constraint{<:Function},O <: Objective{<:Function}}
A struct to model a problem as a set of variables, domains, constraints, and objectives.
```
struct _Model{V <: Variable{<:AbstractDomain},C <: Constraint{<:Function},O <: Objective{<:Function}}
    variables::Dictionary{Int,V}
    constraints::Dictionary{Int,C}
    objectives::Dictionary{Int,O}

    # counter to add new variables: vars, cons, objs
    max_vars::Ref{Int}
    max_cons::Ref{Int}
    max_objs::Ref{Int}

    # Bool to indicate if the _Model instance has been specialized (relatively to types)
    specialized::Ref{Bool}

    # Symbol to indicate the kind of model for specialized methods such as pretty printing
    kind::Symbol
end
```
"""
struct _Model{V <: Variable{<:AbstractDomain},C <: Constraint{<:Function},O <: Objective{<:Function}}# <: MOI.ModelLike
    variables::Dictionary{Int,V}
    constraints::Dictionary{Int,C}
    objectives::Dictionary{Int,O}

    # counter to add new variables: vars, cons, objs
    max_vars::Ref{Int} # TODO: UInt ?
    max_cons::Ref{Int}
    max_objs::Ref{Int}

    # Sense (min = 1, max = -1)
    sense::Ref{Int}

    # Bool to indicate if the _Model instance has been specialized (relatively to types)
    specialized::Ref{Bool}

    # Symbol to indicate the kind of model for specialized methods such as pretty printing
    kind::Symbol

    # Best known bound
    best_bound::Union{Nothing,Float64}

    # Time of construction (seconds) since epoch
    time_stamp::Float64
end

"""
    model()
Construct a _Model, empty by default. It is recommended to add the constraints, variables, and objectives from an empty _Model. The following keyword arguments are available,
- `vars=Dictionary{Int,Variable}()`: collection of variables
- `cons=Dictionary{Int,Constraint}()`: collection of cosntraints
- `objs=Dictionary{Int,Objective}()`: collection of objectives
- `kind=:generic`: the kind of problem modeled (useful for specialized methods such as pretty printing)
"""
function model(;
    vars=Dictionary{Int,Variable}(),
    cons=Dictionary{Int,Constraint}(),
    objs=Dictionary{Int,Objective}(),
    kind=:generic,
    best_bound=nothing,
)

    max_vars = Ref(zero(Int))
    max_cons = Ref(zero(Int))
    max_objs = Ref(zero(Int))
    sense = Ref(one(Int)) # minimization

    specialized = Ref(false)

    _Model(vars, cons, objs, max_vars, max_cons, max_objs, sense, specialized, kind, best_bound, time())
end

"""
    _max_vars(m::M) where M <: Union{Model, AbstractSolver}
Access the maximum variable id that has been attributed to `m`.
"""
_max_vars(m::_Model) = m.max_vars.x

"""
    _max_cons(m::M) where M <: Union{Model, AbstractSolver}
Access the maximum constraint id that has been attributed to `m`.
"""
_max_cons(m::_Model) = m.max_cons.x

"""
    _max_objs(m::M) where M <: Union{Model, AbstractSolver}
Access the maximum objective id that has been attributed to `m`.
"""
_max_objs(m::_Model) = m.max_objs.x

_best_bound(m::_Model) = m.best_bound

"""
    _inc_vars!(m::M) where M <: Union{Model, AbstractSolver}
Increment the maximum variable id that has been attributed to `m`.
"""
_inc_vars!(m::_Model) = m.max_vars.x += 1

"""
    _inc_vars!(m::M) where M <: Union{Model, AbstractSolver}
Increment the maximum constraint id that has been attributed to `m`.
"""
_inc_cons!(m::_Model) = m.max_cons.x += 1

"""
    _inc_vars!(m::M) where M <: Union{Model, AbstractSolver}
Increment the maximum objective id that has been attributed to `m`.
"""
_inc_objs!(m::_Model) = m.max_objs.x += 1

"""
    get_variables(m::M) where M <: Union{Model, AbstractSolver}
Access the variables of `m`.
"""
get_variables(m::_Model) = m.variables

"""
    get_constraints(m::M) where M <: Union{Model, AbstractSolver}
Access the constraints of `m`.
"""
get_constraints(m::_Model) = m.constraints

"""
    get_objectives(m::M) where M <: Union{Model, AbstractSolver}
Access the objectives of `m`.
"""
get_objectives(m::_Model) = m.objectives

"""
    get_kind(m::M) where M <: Union{Model, AbstractSolver}
Access the kind of `m`, such as `:sudoku` or `:generic` (default).
"""
get_kind(m::_Model) = m.kind

"""
    get_variable(m::M, x) where M <: Union{Model, AbstractSolver}
Access the variable `x`.
"""
get_variable(m::_Model, x) = get_variables(m)[x]

"""
    get_constraint(m::M, c) where M <: Union{Model, AbstractSolver}
Access the constraint `c`.
"""
get_constraint(m::_Model, c) = get_constraints(m)[c]

"""
    get_objective(m::M, o) where M <: Union{Model, AbstractSolver}
Access the objective `o`.
"""
get_objective(m::_Model, o) = get_objectives(m)[o]

"""
    get_domain(m::M, x) where M <: Union{Model, AbstractSolver}
Access the domain of variable `x`.
"""
get_domain(m::_Model, x) = get_domain(get_variable(m, x))

"""
    get_name(m::M, x) where M <: Union{Model, AbstractSolver}
Access the name of variable `x`.
"""
get_name(::_Model, x) = "x$x"

"""
    get_cons_from_var(m::M, x) where M <: Union{Model, AbstractSolver}
Access the constraints restricting variable `x`.
"""
get_cons_from_var(m::_Model, x) = _get_constraints(get_variable(m, x))

"""
    get_vars_from_cons(m::M, c) where M <: Union{Model, AbstractSolver}
Access the variables restricted by constraint `c`.
"""
get_vars_from_cons(m::_Model, c) = _get_vars(get_constraint(m, c))

"""
    get_time_stamp(m::M) where M <: Union{Model, AbstractSolver}
Access the time (since epoch) when the model was created. This time stamp is for internal performance measurement.
"""
get_time_stamp(m::_Model) = m.time_stamp

"""
    length_var(m::M, x) where M <: Union{Model, AbstractSolver}
Return the domain length of variable `x`.
"""
length_var(m::_Model, x) = length(get_variable(m, x))

"""
    length_cons(m::M, c) where M <: Union{Model, AbstractSolver}
Return the length of constraint `c`.
"""
length_cons(m::_Model, c) = _length(get_constraint(m, c))

"""
    length_objs(m::M) where M <: Union{Model, AbstractSolver}
Return the number of objectives in `m`.
"""
length_objs(m::_Model) = length(get_objectives(m))

"""
    length_vars(m::M) where M <: Union{Model, AbstractSolver}
Return the number of variables in `m`.
"""
length_vars(m::_Model) = length(get_variables(m))

"""
    length_cons(m::M) where M <: Union{Model, AbstractSolver}
Return the number of constraints in `m`.
"""
length_cons(m::_Model) = length(get_constraints(m))

"""
    draw(m::M, x) where M <: Union{Model, AbstractSolver}
Draw a random value of `x` domain.
"""
draw(m::_Model, x) = rand(get_variable(m, x))
draw(m::_Model, x, n) = rand(get_variable(m, x), n)

"""
    constriction(m::M, x) where M <: Union{Model, AbstractSolver}
Return the constriction of variable `x`.
"""
constriction(m::_Model, x) = _constriction(get_variable(m, x))

"""
    delete_value(m::M, x, val) where M <: Union{Model, AbstractSolver}
Delete `val` from `x` domain.
"""
delete_value!(m::_Model, x, val) = delete!(get_variable(m, x), val)

"""
    delete_var_from_cons(m::M, c, x) where M <: Union{Model, AbstractSolver}
Delete `x` from the constraint `c` list of restricted variables.
"""
delete_var_from_cons!(m::_Model, c, x) = _delete!(get_constraint(m, c), x)

"""
    add_value!(m::M, x, val) where M <: Union{Model, AbstractSolver}
Add `val` to `x` domain.
"""
add_value!(m::_Model, x, val) = add!(get_variable(m, x), val)

"""
    add_var_to_cons!(m::M, c, x) where M <: Union{Model, AbstractSolver}
Add `x` to the constraint `c` list of restricted variables.
"""
add_var_to_cons!(m::_Model, c, x) = _add!(get_constraint(m, c), x)

"""    mts = - get_time_stamp(model)
return TimeStamps(mts, mts, mts, mts, mts, mts, mts)
end

    add!(m::M, x) where M <: Union{Model, AbstractSolver}
    add!(m::M, c) where M <: Union{Model, AbstractSolver}
    add!(m::M, o) where M <: Union{Model, AbstractSolver}
Add a variable `x`, a constraint `c`, or an objective `o` to `m`.
"""
function add!(m::_Model, x::Variable)
    _inc_vars!(m)
    insert!(get_variables(m), _max_vars(m), x)
end

function add!(m::_Model, c::Constraint)
    _inc_cons!(m)
    insert!(get_constraints(m), _max_cons(m), c)
    foreach(x -> _add_to_constraint!(m.variables[x], _max_cons(m)), c.vars)
end

function add!(m::_Model, o::Objective)
    _inc_objs!(m)
    insert!(get_objectives(m), _max_objs(m), o)
end

"""
    variable!(m::M, d) where M <: Union{Model, AbstractSolver}
Add a variable with domain `d` to `m`.
"""
function variable!(m::_Model, d=domain())
    add!(m, variable(d))
    return _max_vars(m)
end

"""
    constraint!(m::M, func, vars) where M <: Union{Model, AbstractSolver}
Add a constraint with an error function `func` defined over variables `vars`.
"""
function constraint!(m::_Model, func, vars::V) where {V <: AbstractVector{<:Number}}
    add!(m, constraint(func, vars))
    return _max_cons(m)
end

"""
    objective!(m::M, func) where M <: Union{Model, AbstractSolver}
Add an objective evaluated by `func`.
"""
function objective!(m::_Model, func)
    add!(m, objective(func, "o" * string(_max_objs(m) + 1)))
end

"""
    describe(m::M) where M <: Union{Model, AbstractSolver}
Describe the model.
"""
function describe(m::_Model) # TODO: rewrite _describe
    objectives = ""
    if Dictionaries.length(m.objectives) == 0
        objectives = "Constraint Satisfaction Program (CSP)"
    else
        objectives = "Constraint Optimization Program (COP) with Objective(s)\n"
        objectives *=
            mapreduce(o -> "\t\t" * o.name * "\n", *, get_objectives(m); init="")[1:end - 1]
    end
    variables = mapreduce(
        x -> "\t\tx$(x[1]): " * string(get_domain(x[2])) * "\n",
        *, pairs(m.variables); init=""
    )[1:end - 1]
    constraints = mapreduce(c -> "\t\tc$(c[1]): " * string(c[2].vars) * "\n", *, pairs(m.constraints); init="")[1:end - 1]

    str =
    """
    _Model description
        $objectives
        Variables: $(length(m.variables))
    $variables
        Constraints: $(length(m.constraints))
    $constraints
    """

    return str
end

"""
    is_sat(m::M) where M <: Union{Model, AbstractSolver}
Return `true` if `m` is a satisfaction model.
"""
is_sat(m::_Model) = length_objs(m) == 0

"""
    is_specialized(m::M) where M <: Union{Model, AbstractSolver}
Return `true` if the model is already specialized.
"""
function is_specialized(m::_Model)
    return m.specialized.x
end

"""
    specialize(m::M) where M <: Union{Model, AbstractSolver}
Specialize the structure of a model to avoid dynamic type attribution at runtime.
"""
function specialize(m::_Model)
    vars_types = Set{Type}()
    cons_types = Set{Type}()
    objs_types = Set{Type}()

    foreach(x -> push!(vars_types, typeof(x.domain)), get_variables(m))
    foreach(c -> push!(cons_types, typeof(c.f)), get_constraints(m))
    foreach(o -> push!(objs_types, typeof(o.f)), get_objectives(m))

    vars_union = _to_union(vars_types)
    cons_union = _to_union(cons_types)
    objs_union = _to_union(objs_types)

    vars = similar(get_variables(m), Variable{vars_union})
    cons = similar(get_constraints(m), Constraint{cons_union})
    objs = similar(get_objectives(m), Objective{objs_union})

    foreach(x -> vars[x] = Variable(vars_union, get_variable(m, x)), keys(vars))
    foreach(c -> cons[c] = Constraint(cons_union, get_constraint(m, c)), keys(cons))
    foreach(o -> objs[o] = Objective(objs_union, get_objective(m, o)), keys(objs))

    max_vars = Ref(_max_vars(m))
    max_cons = Ref(_max_cons(m))
    max_objs = Ref(_max_objs(m))

    specialized = Ref(true)

    _Model(vars, cons, objs, max_vars, max_cons, max_objs, m.sense, specialized,
        get_kind(m), _best_bound(m), get_time_stamp(m))
end

"""
    _is_empty(m::Model)

DOCSTRING
"""
function _is_empty(m::_Model)
    return length_objs(m) + length_vars(m) == 0
end

"""
    _set_domain!(m::Model, x, values)

DOCSTRING

# Arguments:
- `m`: DESCRIPTION
- `x`: DESCRIPTION
- `values`: DESCRIPTION
"""
function _set_domain!(m::_Model, x, values)
    d = domain(values)
    m.variables[x] = Variable(d, get_cons_from_var(m, x))
end

function _set_domain!(m::_Model, x, a::Tuple, b::Tuple)
    d = domain(a, b)
    m.variables[x] = Variable(d, get_cons_from_var(m, x))
end

# function _set_domain!(m::_Model, x,r::R) where {R <: AbstractRange}
#     d = domain(r)
#     m.variables[x] = Variable(d, get_cons_from_var(m, x))
# end

function _set_domain!(m::_Model, x, d::D) where {D <: AbstractDomain}
    m.variables[x] = Variable(d, get_cons_from_var(m, x))
end

"""
    domain_size(m::Model, x) = begin

DOCSTRING
"""
domain_size(m::_Model, x) = domain_size(get_variable(m, x))

"""
    max_domains_size(m::Model, vars) = begin

DOCSTRING
"""
max_domains_size(m::_Model, vars) = maximum(map(x -> domain_size(m, x), vars))

"""
    empty!(m::Model)

DOCSTRING
"""
function Base.empty!(m::_Model)
    empty!(m.variables)
    empty!(m.constraints)
    empty!(m.objectives)
    m.max_vars[] = 0
    m.max_cons[] = 0
    m.max_objs[] = 0
    m.specialized[] = false
end

# Non modificating cost and objective computations

draw(m::_Model) = map(rand, get_variables(m))

compute_cost(c::Constraint, values, X) = apply(c, map(x -> values[x], c.vars), X)
function compute_costs(m, values, X)
    return sum(c -> compute_cost(c, values, X), get_constraints(m); init = 0.0)
end
function compute_costs(m, values, cons, X)
    return  sum(c -> compute_cost(c, values, X), view(get_constraints(m), cons); init = 0.0)
end

compute_objective(m, values; objective = 1) = apply(get_objective(m, objective), values)

function update_domain!(m, x, d)
    if isempty(get_variable(m,x))
        old_d = get_variable(m, x).domain
        _set_domain!(m, x, d.domain)
    else
        old_d = get_variable(m, x).domain
        are_continuous = typeof(d) <: ContinuousDomain && typeof(old_d) <: ContinuousDomain
        new_d = if are_continuous
            intersect_domains(old_d, d)
        else
            intersect_domains(convert(RangeDomain,old_d), convert(RangeDomain, d))
        end
        _set_domain!(m, x, new_d)
    end
end

sense(m::_Model) = m.sense[]
sense!(m::_Model, ::Val{:min}) = m.sense[] = 1
sense!(m::_Model, ::Val{:max}) = m.sense[] = -1
