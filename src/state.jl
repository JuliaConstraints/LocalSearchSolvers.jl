abstract type AbstractState end

struct EmptyState <: AbstractState end

abstract type AbstractStateIndexing end
struct DenseStateIndexing <: AbstractStateIndexing end
struct SparseStateIndexing <: AbstractStateIndexing end

"""
    GeneralState{T <: Number}
A mutable structure to store the general state of a solver. All methods applied to `GeneralState` are forwarded to `S <: AbstractSolver`.
```
mutable struct GeneralState{T <: Number} <: AbstractState
    configuration::Configuration{T}
    cons_costs::Dictionary{Int, Float64}
    last_improvement::Int
    tabu::Dictionary{Int, Int}
    vars_costs::Dictionary{Int, Float64}
end
```
"""
mutable struct _State{T, I, D <: AbstractStateIndexing} <: AbstractState
    configuration::Configuration{T}
    cons_costs::Dictionary{Int, Float64}
    fluct::Fluct
    constraint_input::Vector{T}
    icn_computations::Matrix{Float64}
    neighborhood::NeighborhoodWorkspace{T}
    invariants::I
    indexing::D
    has_incremental::Bool
    optimizing::Bool
    last_improvement::Int
    vars_costs::Dictionary{Int, Float64}
end

@forward _State.configuration get_values, get_error, get_value, compute_cost!, set_values!
@forward _State.configuration set_value!, set_sat!

const State = Union{EmptyState, _State}

state() = EmptyState()
function _constraint_input(config::Configuration{T}, m::_Model) where {T}
    max_arity = maximum(c -> length(c.vars), get_constraints(m); init = 0)
    return Vector{T}(undef, max_arity)
end

function state(m::_Model, pool = pool(); opt = false)
    X = Matrix{Float64}(undef, m.max_vars[], CompositionalNetworks.max_icn_length())
    lc, lv = length_cons(m) > 0, length_vars(m) > 0
    config = Configuration(m, X)
    input = _constraint_input(config, m)
    neighborhood = _neighborhood_workspace(config, m)
    invariants, has_incremental = _constraint_invariants(m, config, X, input)
    indexing = _state_indexing(m)
    cons = lc ? zeros(Float64, get_constraints(m)) : Dictionary{Int, Float64}()
    last_improvement = 0
    vars = lv ? zeros(Float64, get_variables(m)) : Dictionary{Int, Float64}()
    fluct = Fluct(cons, vars)
    return _State(config, cons, fluct, input, X, neighborhood, invariants, indexing,
        has_incremental, opt, last_improvement, vars)
end

function _has_dense_ids(collection, maximum_id)
    length(collection) == maximum_id || return false
    for (position, id) in enumerate(keys(collection))
        position == id || return false
    end
    return true
end

function _state_indexing(model)
    dense = _has_dense_ids(get_variables(model), _max_vars(model)) &&
            _has_dense_ids(get_constraints(model), _max_cons(model))
    return dense ? DenseStateIndexing() : SparseStateIndexing()
end

# Dictionaries.Dictionary stores values contiguously and preserves its index order. Model ids
# are normally allocated as 1:n in that same order, so the dense policy can bypass hashing in
# the candidate loop while the sparse policy preserves dictionary semantics for future models
# with holes or reordered ids. Keep this low-level dependency isolated in these accessors.
@inline _state_value(values::Dictionary, id, ::DenseStateIndexing) =
    @inbounds getfield(values, :values)[id]
@inline _state_value(values::Dictionary, id, ::SparseStateIndexing) = values[id]

@inline _state_container(values::Dictionary, ::DenseStateIndexing) =
    getfield(values, :values)
@inline _state_container(values::Dictionary, ::SparseStateIndexing) = values
@inline _state_assignment(state::_State) =
    _state_container(_values(state), state.indexing)

@inline _state_cost(values::Dictionary, id, ::DenseStateIndexing) =
    @inbounds getfield(values, :values)[id]
@inline _state_cost(values::Dictionary, id, ::SparseStateIndexing) = get!(values, id, 0.0)

@inline function _state_value!(values::Dictionary, id, value, ::DenseStateIndexing)
    @inbounds getfield(values, :values)[id] = value
    return value
end
@inline function _state_value!(values::Dictionary, id, value, ::SparseStateIndexing)
    values[id] = value
    return value
end

_constraint_input(s::_State) = s.constraint_input
_neighborhood_workspace(s::_State) = s.neighborhood

_neighborhood_workspace(config::Configuration{T}, model) where {T} =
    NeighborhoodWorkspace(T, model)
_invariants(s::_State) = s.invariants
_invariant(s::_State, constraint) = _state_value(_invariants(s), constraint, s.indexing)
_has_incremental(s::_State) = s.has_incremental

function _constraint_invariants(model, configuration, external, input)
    has_incremental = any(
        constraint -> supports_incremental(constraint.f), get_constraints(model))
    has_incremental || return nothing, false

    built = map(pairs(get_constraints(model))) do (id, constraint)
        values = constraint_input!(input, constraint, get_values(configuration))
        id => initialize_invariant(constraint.f, values; X = external)
    end
    isempty(built) && return nothing, false

    invariant_type = _to_union(typeof(last(pair)) for pair in built)
    invariants = Dictionary{Int, invariant_type}()
    foreach(pair -> insert!(invariants, first(pair), last(pair)), built)
    return invariants, true
end

"""
    _cons_costs(s::S) where S <: Union{_State, AbstractSolver}
Access the constraints costs.
"""
_cons_costs(s::_State) = s.cons_costs

"""
    _vars_costs(s::S) where S <: Union{_State, AbstractSolver}
Access the variables costs.
"""
_vars_costs(s::_State) = s.vars_costs

"""
    _vars_costs(s::S) where S <: Union{_State, AbstractSolver}
Access the variables costs.
"""
_values(s::_State) = get_values(s)

"""
    _optimizing(s::S) where S <: Union{_State, AbstractSolver}
Check if `s` is in an optimizing state.
"""
_optimizing(s::_State) = s.optimizing

"""
    _cons_costs!(s::S, costs) where S <: Union{_State, AbstractSolver}
Set the constraints costs.
"""
_cons_costs!(s::_State, costs) = s.cons_costs = costs

"""
    _vars_costs!(s::S, costs) where S <: Union{_State, AbstractSolver}
Set the variables costs.
"""
_vars_costs!(s::_State, costs) = s.vars_costs = costs

"""
    _values!(s::S, values) where S <: Union{_State, AbstractSolver}
Set the variables values.
"""
_values!(s::_State{T}, values) where {T <: Number} = set_values!(s, values)

"""
    _optimizing!(s::S) where S <: Union{_State, AbstractSolver}
Set the solver `optimizing` status to `true`.
"""
_optimizing!(s::_State) = s.optimizing = true

"""
    _satisfying!(s::S) where S <: Union{_State, AbstractSolver}
Set the solver `optimizing` status to `false`.
"""
_satisfying!(s::_State) = s.optimizing = false

"""
    _cons_cost(s::S, c) where S <: Union{_State, AbstractSolver}
Return the cost of constraint `c`.
"""
_cons_cost(s::_State, c) = _state_cost(_cons_costs(s), c, s.indexing)

"""
    _var_cost(s::S, x) where S <: Union{_State, AbstractSolver}
Return the cost of variable `x`.
"""
_var_cost(s::_State, x) = _state_cost(_vars_costs(s), x, s.indexing)

"""
    _value(s::S, x) where S <: Union{_State, AbstractSolver}
Return the value of variable `x`.
"""
_value(s::_State, x) = _state_value(_values(s), x, s.indexing)

"""
    _cons_cost!(s::S, c, cost) where S <: Union{_State, AbstractSolver}
Set the `cost` of constraint `c`.
"""
_cons_cost!(s::_State, c, cost) = _state_value!(_cons_costs(s), c, cost, s.indexing)

"""
    _var_cost!(s::S, x, cost) where S <: Union{_State, AbstractSolver}
Set the `cost` of variable `x`.
"""
_var_cost!(s::_State, x, cost) = _state_value!(_vars_costs(s), x, cost, s.indexing)

"""
    _value!(s::S, x, val) where S <: Union{_State, AbstractSolver}
Set the value of variable `x` to `val`.
"""
_value!(s::_State, x, val) = _state_value!(_values(s), x, val, s.indexing)

"""
    _set!(s::S, x, val) where S <: Union{_State, AbstractSolver}
Set the value of variable `x` to `val`.
"""
_set!(s::_State, x, val) = set!(_values(s), x, val)

"""
    _set!(s::S, x, y) where S <: Union{_State, AbstractSolver}
Swap the values of variables `x` and `y`.
"""
function _swap_value!(s::_State, x, y)
    aux = _value(s, x)
    _value!(s, x, _value(s, y))
    _value!(s, y, aux)
end

_last_improvement(s::_State) = s.last_improvement
_inc_last_improvement!(s::_State) = s.last_improvement += 1
_reset_last_improvement!(s::_State) = s.last_improvement = 0

has_solution(s::_State) = is_solution(s.configuration)

function set_error!(s::_State, err)
    sat = err ≈ 0.0
    set_sat!(s, sat)
    set_value!(s, sat ? 0.0 : err)
end

get_error(::EmptyState) = Inf

@testitem "State indexing selects dense access without changing dictionary APIs" default_imports = false begin
    import ConstraintDomains: domain
    import LocalSearchSolvers as LS
    import Test: @inferred, @test

    model = LS.model()
    foreach(_ -> LS.variable!(model, domain(1:3)), 1:3)
    LS.constraint!(model, (values; X) -> abs(sum(values) - 4), [1, 2, 3])
    solver = LS.solver(model; options = LS.Options(
        print_level = :silent,
        iteration = 1,
        process_threads_map = Dict(1 => 1),
    ))
    LS._init!(solver)

    @test solver.state.indexing isa LS.DenseStateIndexing
    @test LS._cons_costs(solver) isa LS.Dictionary
    @test LS._vars_costs(solver) isa LS.Dictionary
    @test LS._values(solver) isa LS.Dictionary

    state = LS._search_context(solver).state
    @test @inferred(LS._value(state, 2)) == LS._values(state)[2]
    @test @inferred(LS._cons_cost(state, 1)) == LS._cons_costs(state)[1]
    @test @inferred(LS._var_cost(state, 2)) == LS._vars_costs(state)[2]

    LS._value!(solver, 2, 3)
    LS._cons_cost!(solver, 1, 2.5)
    LS._var_cost!(solver, 2, 1.5)
    @test LS._values(solver)[2] == 3
    @test LS._cons_costs(solver)[1] == 2.5
    @test LS._vars_costs(solver)[2] == 1.5
end

@testitem "Sparse state indexing preserves keyed fallback semantics" default_imports = false begin
    import Dictionaries: Dictionary
    import LocalSearchSolvers as LS
    import Test: @test

    values = Dictionary([2, 4], [20, 40])
    indexing = LS.SparseStateIndexing()
    @test LS._state_value(values, 4, indexing) == 40
    LS._state_value!(values, 2, 21, indexing)
    @test values[2] == 21

    costs = Dictionary([2, 4], [2.0, 4.0])
    @test LS._state_cost(costs, 6, indexing) == 0.0
    @test costs[6] == 0.0
end
