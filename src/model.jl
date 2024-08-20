"""
    Model{V <: Variable{<:AbstractDomain},C <: Constraint{<:Function},O <: Objective{<:Function}}

A struct to model a problem as a set of variables, domains, constraints, and objectives.

# Fields
- `variables::Dictionary{Int,V}`: collection of variables
- `constraints::Dictionary{Int,C}`: collection of constraints
- `objectives::Dictionary{Int,O}`: collection of objectives
- `max_vars::Ref{Int}`: counter to add new variables: vars, cons, objs
- `max_cons::Ref{Int}`: counter to add new variables: vars, cons, objs
- `max_objs::Ref{Int}`: counter to add new variables: vars, cons, objs
- `specialized::Ref{Bool}`: Bool to indicate if the Model instance has been specialized (relatively to types). This is useful for performance optimization of models with static types.
- `kind::Symbol`: Symbol to indicate the kind of model for specialized methods such as pretty printing
- `best_bound::Union{Nothing, Float64}`: Best known bound (in the case of optimization problems)
- `time_stamp::Float64`: Time of construction (seconds) since epoch
"""
struct Model{V <: Variable{<:AbstractDomain},
    C <: Constraint{<:Function}, O <: Objective{<:Function}}# <: MOI.ModelLike
    variables::Dictionary{Int, V}
    constraints::Dictionary{Int, C}
    objectives::Dictionary{Int, O}

    # counter to add new variables: vars, cons, objs
    max_vars::Ref{Int} # TODO: UInt ?
    max_cons::Ref{Int}
    max_objs::Ref{Int}

    # Sense (min = 1, max = -1)
    sense::Ref{Int}

    # Bool to indicate if the Model instance has been specialized (relatively to types)
    specialized::Ref{Bool}

    # Symbol to indicate the kind of model for specialized methods such as pretty printing
    kind::Symbol

    # Best known bound
    best_bound::Union{Nothing, Float64}

    # Time of construction (seconds) since epoch
    time_stamp::Float64
end

"""
    model(; keyargs...)

Construct a Model, empty by default. It is recommended to add the constraints, variables, and objectives from an empty Model. The following keyword arguments are available,
- `vars=Dictionary{Int,Variable}()`: collection of variables
- `cons=Dictionary{Int,Constraint}()`: collection of constraints
- `objs=Dictionary{Int,Objective}()`: collection of objectives
- `kind=:generic`: the kind of problem modeled (useful for specialized methods such as pretty printing)
- `best_bound=nothing`: best known bound (in the case of optimization problems)
"""
function model(;
        vars = Dictionary{Int, Variable}(),
        cons = Dictionary{Int, Constraint}(),
        objs = Dictionary{Int, Objective}(),
        kind = :generic,
        best_bound = nothing
)
    max_vars = Ref(zero(Int))
    max_cons = Ref(zero(Int))
    max_objs = Ref(zero(Int))
    sense = Ref(one(Int)) # minimization

    specialized = Ref(false)

    Model(vars, cons, objs, max_vars, max_cons, max_objs,
        sense, specialized, kind, best_bound, time())
end

"""
    max_vars(m::M) where M <: Union{Model, AbstractSolver}

Access the maximum variable id that has been attributed to `m`.
"""
max_vars(m::Model) = m.max_vars.x

"""
    max_cons(m::M) where M <: Union{Model, AbstractSolver}

Access the maximum constraint id that has been attributed to `m`.
"""
max_cons(m::Model) = m.max_cons.x

"""
    max_objs(m::M) where M <: Union{Model, AbstractSolver}

Access the maximum objective id that has been attributed to `m`.
"""
max_objs(m::Model) = m.max_objs.x

"""
    best_bound(m::M) where M <: Union{Model, AbstractSolver}

Access the best known bound of `m`.
"""
best_bound(m::Model) = m.best_bound

"""
    inc_vars!(m::M) where M <: Union{Model, AbstractSolver}
Increment the maximum variable id that has been attributed to `m`.
"""
inc_vars!(m::Model) = m.max_vars.x += 1

"""
    inc_vars!(m::M) where M <: Union{Model, AbstractSolver}
Increment the maximum constraint id that has been attributed to `m`.
"""
inc_cons!(m::Model) = m.max_cons.x += 1

"""
    inc_vars!(m::M) where M <: Union{Model, AbstractSolver}
Increment the maximum objective id that has been attributed to `m`.
"""
inc_objs!(m::Model) = m.max_objs.x += 1

"""
    get_variables(m::M) where M <: Union{Model, AbstractSolver}
Access the variables of `m`.
"""
get_variables(m::Model) = m.variables

"""
    get_constraints(m::M) where M <: Union{Model, AbstractSolver}
Access the constraints of `m`.
"""
get_constraints(m::Model) = m.constraints

"""
    get_objectives(m::M) where M <: Union{Model, AbstractSolver}
Access the objectives of `m`.
"""
get_objectives(m::Model) = m.objectives

"""
    get_kind(m::M) where M <: Union{Model, AbstractSolver}
Access the kind of `m`, such as `:sudoku` or `:generic` (default).
"""
get_kind(m::Model) = m.kind

"""
    get_variable(m::M, x) where M <: Union{Model, AbstractSolver}
Access the variable `x`.
"""
get_variable(m::Model, x) = get_variables(m)[x]

"""
    get_constraint(m::M, c) where M <: Union{Model, AbstractSolver}
Access the constraint `c`.
"""
get_constraint(m::Model, c) = get_constraints(m)[c]

"""
    get_objective(m::M, o) where M <: Union{Model, AbstractSolver}
Access the objective `o`.
"""
get_objective(m::Model, o) = get_objectives(m)[o]

"""
    get_domain(m::M, x) where M <: Union{Model, AbstractSolver}
Access the domain of variable `x`.
"""
get_domain(m::Model, x) = get_domain(get_variable(m, x))

"""
    get_name(m::M, x) where M <: Union{Model, AbstractSolver}
Access the name of variable `x`.
"""
get_name(::Model, x) = "x$x"

"""
    get_cons_from_var(m::M, x) where M <: Union{Model, AbstractSolver}
Access the constraints restricting variable `x`.
"""
get_cons_from_var(m::Model, x) = get_constraints(get_variable(m, x))

"""
    get_vars_from_cons(m::M, c) where M <: Union{Model, AbstractSolver}
Access the variables restricted by constraint `c`.
"""
get_vars_from_cons(m::Model, c) = get_vars(get_constraint(m, c))

"""
    get_time_stamp(m::M) where M <: Union{Model, AbstractSolver}
Access the time (since epoch) when the model was created. This time stamp is for internal performance measurement.
"""
get_time_stamp(m::Model) = m.time_stamp

"""
    length_var(m::M, x) where M <: Union{Model, AbstractSolver}
Return the domain length of variable `x`.
"""
length_var(m::Model, x) = length(get_variable(m, x))

"""
    length_cons(m::M, c) where M <: Union{Model, AbstractSolver}
Return the length of constraint `c`.
"""
length_cons(m::Model, c) = length(get_constraint(m, c))

"""
    length_objs(m::M) where M <: Union{Model, AbstractSolver}
Return the number of objectives in `m`.
"""
length_objs(m::Model) = length(get_objectives(m))

"""
    length_vars(m::M) where M <: Union{Model, AbstractSolver}
Return the number of variables in `m`.
"""
length_vars(m::Model) = length(get_variables(m))

"""
    length_cons(m::M) where M <: Union{Model, AbstractSolver}
Return the number of constraints in `m`.
"""
length_cons(m::Model) = length(get_constraints(m))

"""
    draw(m::M, x) where M <: Union{Model, AbstractSolver}
Draw a random value from a model `m` of `x` domain.
"""
draw(m::Model, x) = rand(get_variable(m, x))
draw(m::Model, x, n) = rand(get_variable(m, x), n)

"""
    constriction(m::M, x) where M <: Union{Model, AbstractSolver}
Return the constriction of variable `x`.
"""
constriction(m::Model, x) = constriction(get_variable(m, x))

"""
    delete_value(m::M, x, val) where M <: Union{Model, AbstractSolver}
Delete `val` from `x` domain.
"""
delete_value!(m::Model, x, val) = delete!(get_variable(m, x), val)

"""
    delete_var_from_cons(m::M, c, x) where M <: Union{Model, AbstractSolver}
Delete `x` from the constraint `c` list of restricted variables.
"""
delete_var_from_cons!(m::Model, c, x) = delete!(get_constraint(m, c), x)

"""
    add_value!(m::M, x, val) where M <: Union{Model, AbstractSolver}
Add `val` to `x` domain.
"""
add_value!(m::Model, x, val) = add!(get_variable(m, x), val)

"""
    add_var_to_cons!(m::M, c, x) where M <: Union{Model, AbstractSolver}
Add `x` to the constraint `c` list of restricted variables.
"""
add_var_to_cons!(m::Model, c, x) = add!(get_constraint(m, c), x)

"""
    add!(m::M, x) where M <: Union{Model, AbstractSolver}
    add!(m::M, c) where M <: Union{Model, AbstractSolver}
    add!(m::M, o) where M <: Union{Model, AbstractSolver}

Add a variable `x`, a constraint `c`, or an objective `o` to `m`.
"""
function add!(m::Model, x::Variable)
    inc_vars!(m)
    insert!(get_variables(m), max_vars(m), x)
end

function add!(m::Model, c::Constraint)
    inc_cons!(m)
    insert!(get_constraints(m), max_cons(m), c)
    foreach(x -> add_to_constraint!(m.variables[x], max_cons(m)), c.vars)
end

function add!(m::Model, o::Objective)
    inc_objs!(m)
    insert!(get_objectives(m), max_objs(m), o)
end

"""
    variable!(m::M, d) where M <: Union{Model, AbstractSolver}
Add a variable with domain `d` to `m`.
"""
function variable!(m::Model, d = domain())
    add!(m, variable(d))
    return max_vars(m)
end

"""
    constraint!(m::M, func, vars) where M <: Union{Model, AbstractSolver}
Add a constraint with an error function `func` defined over variables `vars`.
"""
function constraint!(m::Model, func, vars::V) where {V <: AbstractVector{<:Number}}
    add!(m, constraint(func, vars))
    return max_cons(m)
end

"""
    objective!(m::M, func) where M <: Union{Model, AbstractSolver}
Add an objective evaluated by `func`.
"""
function objective!(m::Model, func)
    add!(m, objective(func, "o" * string(max_objs(m) + 1)))
end

"""
    is_sat(m::M) where M <: Union{Model, AbstractSolver}
Return `true` if `m` is a satisfaction model.
"""
is_sat(m::Model) = length_objs(m) == 0

"""
    is_specialized(m::M) where M <: Union{Model, AbstractSolver}
Return `true` if the model is already specialized.
"""
is_specialized(m::Model) = m.specialized[]

"""
    specialize(m::M) where M <: Union{Model, AbstractSolver}
Specialize the structure of a model to avoid dynamic type attribution at runtime.
"""
function specialize(m::Model)
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

    maxvars = Ref(max_vars(m))
    maxcons = Ref(max_cons(m))
    maxobjs = Ref(max_objs(m))

    specialized = Ref(true)

    Model(vars, cons, objs, maxvars, maxcons, maxobjs, m.sense, specialized,
        get_kind(m), best_bound(m), get_time_stamp(m))
end

"""
    is_empty(m::Model)

Check if the model is empty.
"""
is_empty(m::Model) = length_objs(m) + length_vars(m) == 0

"""
    set_domain!(m::Model, x, values) # [1]
    set_domain!(m::Model, x, a::Tuple, b::Tuple) # [2]
    set_domain!(m::Model, x, d::D) where {D <: AbstractDomain} # [3]

Set the domain of variable `x` to `values`. The domain can be a collection of values or a range.

# Arguments
- `m::Model`: the model
- `x`: the variable id
- `values`: the domain values [1]
- `a::Tuple`: the lower bound of the range [2]
- `b::Tuple`: the upper bound of the range [2]
- `d::D`: the domain [3]
"""
function set_domain!(m::Model, x, values)
    d = domain(values)
    m.variables[x] = Variable(d, get_cons_from_var(m, x))
end

function set_domain!(m::Model, x, a::Tuple, b::Tuple)
    d = domain(a, b)
    m.variables[x] = Variable(d, get_cons_from_var(m, x))
end

function set_domain!(m::Model, x, d::D) where {D <: AbstractDomain}
    m.variables[x] = Variable(d, get_cons_from_var(m, x))
end

"""
    domain_size(m::Model, x)

Return the size of the domain of variable `x`.
"""
domain_size(m::Model, x) = domain_size(get_variable(m, x))

"""
    max_domains_size(m::Model, vars)

Return the maximum domain size of a collection of variables.
"""
max_domains_size(m::Model, vars) = maximum(map(x -> domain_size(m, x), vars))

"""
    empty!(m::Model)

Empty the model.
"""
function Base.empty!(m::Model)
    empty!(m.variables)
    empty!(m.constraints)
    empty!(m.objectives)
    m.max_vars[] = 0
    m.max_cons[] = 0
    m.max_objs[] = 0
    m.specialized[] = false
end

"""
    draw(m::Model)

Draw random values from the domains of the variables in `m`.
"""
draw(m::Model) = map(rand, get_variables(m))

"""
    compute_costs(m::Model, values, X) # [1]
    compute_costs(m::Model, values, cons, X) # [2]

Compute the costs of the constraints in `m` given the values of the variables in `values`.

# Arguments
- `m::Model`: the model
- `values`: the values of the variables
- `cons`: the constraints to consider [2]
- `X`: a configuration
"""
function compute_costs(m::Model, values, X)
    return sum(c -> compute_cost(c, values, X), get_constraints(m); init = 0.0)
end
function compute_costs(m::Model, values, cons, X)
    return sum(c -> compute_cost(c, values, X), view(get_constraints(m), cons); init = 0.0)
end

"""
    compute_objective(m::Model, values, objective)

Compute the objective of `m` given the values of the variables in `values`.
"""
compute_objective(m::Model, values; objective = 1) = apply(
    get_objective(m, objective), values)

"""
    update_domain!(m::Model, x, d)

Update the domain of variable `x` with `d`.
"""
function update_domain!(m::Model, x, d)
    if isempty(get_variable(m, x))
        old_d = get_variable(m, x).domain
        set_domain!(m, x, d.domain)
    else
        old_d = get_variable(m, x).domain
        are_continuous = typeof(d) <: ContinuousDomain && typeof(old_d) <: ContinuousDomain
        new_d = if are_continuous
            intersect_domains(old_d, d)
        else
            intersect_domains(convert(RangeDomain, old_d), convert(RangeDomain, d))
        end
        set_domain!(m, x, new_d)
    end
end

"""
    sense(m::Model)

Return the sense of the model. Mainly to figure out if it is a minimization or maximization problem.
"""
sense(m::Model) = m.sense[]

"""
    sense!(m::Model, ::Val{:min})
    sense!(m::Model, ::Val{:max})

Set the sense of the model to minimization or maximization.
"""
sense!(m::Model, ::Val{:min}) = m.sense[] = 1
sense!(m::Model, ::Val{:max}) = m.sense[] = -1

"""
    describe(m::Model)

Provide a detailed description of the model, including the type of problem (CSP or COP), the sense (minimization or maximization), the kind, the number and details of variables, constraints, and objectives.
"""
function describe(m::Model)
    # Determine if the model is CSP or COP
    model_type = is_sat(m) ? "Constraint Satisfaction Problem (CSP)" :
                 "Constraint Optimization Problem (COP)"

    # Determine the sense of the model
    sense_str = sense(m) == 1 ? "Minimization" : "Maximization"

    # Retrieve the kind of model
    model_kind = get_kind(m)

    # Format objectives
    objectives_str = if length_objs(m) > 0
        obj_details = join(
            ["\t\tObjective $(i): $(o)" for (i, o) in enumerate(values(get_objectives(m)))],
            "\n")
        "Objectives:\n$obj_details"
    else
        "No objectives defined."
    end

    # Format variables
    variables_str = if length_vars(m) > 0
        var_details = mapreduce(
            x -> "\t\tx$(x[1]): " * string(get_domain(x[2])) * "\n",
            *, pairs(m.variables); init = ""
        )[1:(end - 1)]
        "Variables: $(length_vars(m))\n$var_details"
    else
        "No variables defined."
    end

    # Format constraints
    constraints_str = if length_cons(m) > 0
        con_details = mapreduce(c -> "\t\tc$(c[1]): " * string(c[2].vars) * "\n",
            *, pairs(m.constraints); init = "")[1:(end - 1)]
        "Constraints: $(length_cons(m))\n$con_details"
    else
        "No constraints defined."
    end

    # Include best known bound if available
    best_bound_str = isnothing(best_bound(m)) ? "No bound available." :
                     "Best known bound: $(best_bound(m))"

    # Construct the complete description
    description = """
    Model Description:
    Type: $model_type
    Sense: $sense_str
    Kind: $model_kind
    $objectives_str
    $variables_str
    $constraints_str
    $best_bound_str
    Time of construction: $(get_time_stamp(m)) seconds since epoch
    """

    return description
end

@testitem "Model" tags=[:model] begin
    import LocalSearchSolvers: is_empty, length_vars, length_cons, length_objs, is_sat
    import LocalSearchSolvers: is_specialized, sense, get_kind, get_time_stamp, describe
    import LocalSearchSolvers: variable!, constraint!, objective!, update_domain!
    import LocalSearchSolvers: max_domains_size, specialize, empty!

    m = model()
    @test is_empty(m)
    @test length_vars(m) == 0
    @test length_cons(m) == 0
    @test length_objs(m) == 0
    @test is_sat(m)
    @test !is_specialized(m)
    @test sense(m) == 1
    @test get_kind(m) == :generic
    @test is_empty(m)
    @test get_time_stamp(m) isa Float64
    @test describe(m) isa String

    x = variable!(m)
    y = variable!(m)
    z = variable!(m)
    @test length_vars(m) == 3
    @test !is_empty(m)

    constraint!(m, sum, [x, y, z])
    @test length_cons(m) == 1

    objective!(m, x -> x[1] - x[2] + x[3])
    @test length_objs(m) == 1

    update_domain!(m, x, domain(1:10))
    update_domain!(m, y, domain(1:5))
    update_domain!(m, z, domain(1:2))

    @test max_domains_size(m, [x, y, z]) == 9

    m_special = specialize(m)
    @test is_specialized(m_special)

    println(describe(m))
    println(describe(m_special))

    empty!(m)
    @test is_empty(m)

    println(describe(m))
end
