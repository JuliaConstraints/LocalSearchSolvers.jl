abstract type TabuStrategy end

"""
    EventTabu(local_tenure; selected_tenure=0, clock=:accepted)

Tabu durations counted in accepted moves or in proposals (`clock=:proposal`).
Unlike compatibility tabu, zero means no insertion. Rejected local minima and
plateaus can mark a variable without advancing the accepted-move clock.
"""
struct EventTabu{Clock} <: TabuStrategy
    tabu_tenure::Int
    pick_tenure::Int
    tabu_list::Dictionary{Int,Int}
end
function EventTabu(local_tenure; selected_tenure=0, clock=:accepted)
    local_tenure >= 0 && selected_tenure >= 0 || throw(ArgumentError("negative tabu tenure"))
    clock in (:accepted, :proposal) || throw(ArgumentError("tabu clock must be :accepted or :proposal"))
    EventTabu{clock}(local_tenure, selected_tenure, Dictionary{Int,Int}())
end
tenure(ts::EventTabu, ::Val{:pick}) = ts.pick_tenure
function insert_tabu!(ts::EventTabu, x, kind)
    duration = tenure(ts, kind)
    duration > 0 && set!(tabu_list(ts), x, duration)
    return nothing
end
_advance_proposal_tabu!(ts, event) = decay_tabu!(ts)
_advance_proposal_tabu!(ts::EventTabu{:accepted}, event) =
    event === :accepted ? decay_tabu!(ts) : nothing
_advance_proposal_tabu!(ts::EventTabu{:proposal}, event) = decay_tabu!(ts)
export EventTabu

struct NoTabu <: TabuStrategy end

struct KeenTabu <: TabuStrategy
    tabu_tenure::Int
    tabu_list::Dictionary{Int, Int}
end

struct WeakTabu <: TabuStrategy
    tabu_tenure::Int
    pick_tenure::Int
    tabu_list::Dictionary{Int, Int}
end

tabu() = NoTabu()
function tabu(tabu_tenure)
    tabu_list = Dictionary{Int, Int}()
    return KeenTabu(tabu_tenure, tabu_list)
end
function tabu(tabu_tenure, pick_tenure)
    tabu_list = Dictionary{Int, Int}()
    return WeakTabu(tabu_tenure, pick_tenure, tabu_list)
end

tenure(strategy, ::Val{:tabu}) = strategy.tabu_tenure
tenure(strategy::WeakTabu, ::Val{:pick}) = strategy.pick_tenure
tenure(::TabuStrategy, ::Val{:pick}) = zero(Int)
tenure(::NoTabu, ::Val{:tabu}) = zero(Int)
tenure(strategy, field) = tenure(strategy, Val(field))

"""
    _tabu(s::S) where S <: Union{_State, AbstractSolver}
Access the list of tabu variables.
"""
tabu_list(ts) = ts.tabu_list
tabu_list(::NoTabu) = nothing

"""
    _tabu(s::S, x) where S <: Union{_State, AbstractSolver}
Return the tabu value of variable `x`.
"""
tabu_value(ts, x) = tabu_list(ts)[x]

"""
    _decrease_tabu!(s::S, x) where S <: Union{_State, AbstractSolver}
Decrement the tabu value of variable `x`.
"""
decrease_tabu!(ts, x) = tabu_list(ts)[x] -= 1
decrease_tabu!(::NoTabu, x) = nothing

"""
    _delete_tabu!(s::S, x) where S <: Union{_State, AbstractSolver}
Delete the tabu entry of variable `x`.
"""
delete_tabu!(ts, x) = delete!(tabu_list(ts), x)
delete_tabu!(::NoTabu, x) = nothing

"""
    _empty_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Empty the tabu list.
"""
# Filtering clears entries through the public API and retains the index buffers
# for subsequent insertions. Decay below never deletes during a live traversal.
empty_tabu!(ts) = _clear_tabu_entries!(tabu_list(ts))
_clear_tabu_entries!(table) = filter!(_ -> false, table)
_clear_tabu_entries!(table::Dictionary{Int,Int}) =
    isempty(table) ? table : filter!(_ -> false, table)
empty_tabu!(::NoTabu) = nothing

"""
    _length_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Return the length of the tabu list.
"""
length_tabu(ts) = length(tabu_list(ts))
length_tabu(::NoTabu) = 0

"""
    _insert_tabu!(s::S, x, tabu_time) where S <: Union{_State, AbstractSolver}
Insert the bariable `x` as tabu for `tabu_time`.
"""
function insert_tabu!(ts::KeenTabu, x, ::Val{:tabu})
    set!(tabu_list(ts), x, max(1, tenure(ts, :tabu)))
end
insert_tabu!(::KeenTabu, x, ::Val) = nothing
insert_tabu!(ts::KeenTabu, x, kind::Symbol) = insert_tabu!(ts, x, Val(kind))
insert_tabu!(ts::WeakTabu, x, kind) = set!(tabu_list(ts), x, max(1, tenure(ts, kind)))
insert_tabu!(::NoTabu, x, kind) = nothing

@testitem "Tabu insertion renews an aspirated entry" default_imports=false begin
    import LocalSearchSolvers as LS
    import Test: @test

    strategy = LS.tabu(4, 2)
    LS.insert_tabu!(strategy, 3, :tabu)
    LS.decrease_tabu!(strategy, 3)
    LS.insert_tabu!(strategy, 3, :tabu)
    @test LS.tabu_value(strategy, 3) == 4
end

"""
    _decay_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Decay the tabu list.
"""
function decay_tabu!(ts)
    return _decay_tabu_entries!(tabu_list(ts))
end

function _decay_tabu_entries!(table::Dictionary)
    # Structural deletion during iteration can compact Dictionary indices and
    # skip the next entry. Filter first, then only mutate values in a stable pass.
    filter!(!=(1), table)
    # Matching indices let Dictionaries update values without hashing each key.
    map!(remaining -> remaining - 1, table, table)
    return nothing
end

function _decay_tabu_entries!(table::Dictionary{Int,Int})
    isempty(table) && return nothing
    # Filtering also rebuilds the Dictionary's indices. Integer tabu entries
    # need that structural pass only when a duration actually expires.
    any(==(1),table) && filter!(!=(1),table)
    map!(remaining -> remaining - 1,table,table)
    return nothing
end

function _decay_tabu_entries!(table)
    # Preserve the generic collection protocol for external tabu strategies.
    for (variable, remaining) in collect(pairs(table))
        remaining == 1 ? delete!(table, variable) : (table[variable] = remaining - 1)
    end
    return nothing
end
decay_tabu!(::NoTabu) = nothing

@testitem "NoTabu is an executable strategy" default_imports=false begin
    import LocalSearchSolvers as LS
    import Test: @test

    strategy = LS.tabu()
    @test LS.tabu_list(strategy) === nothing
    @test LS.length_tabu(strategy) == 0
    @test LS.decay_tabu!(strategy) === nothing
    @test LS.empty_tabu!(strategy) === nothing
end
