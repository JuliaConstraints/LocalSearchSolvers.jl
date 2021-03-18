abstract type TabuStrategy end

struct NoTabu <: TabuStrategy end

struct KeenTabu <: TabuStrategy
    tabu_tenure::Int
    tabu_list::Dictionary{Int,Int}
end

struct WeakTabu <: TabuStrategy
    tabu_tenure::Int
    pick_tenure::Int
    tabu_list::Dictionary{Int,Int}
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

"""
    _delete_tabu!(s::S, x) where S <: Union{_State, AbstractSolver}
Delete the tabu entry of variable `x`.
"""
delete_tabu!(ts, x) = delete!(tabu_list(ts), x)

"""
    _empty_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Empty the tabu list.
"""
empty_tabu!(ts) = Dictionaries.empty!(tabu_list(ts))

"""
    _length_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Return the length of the tabu list.
"""
length_tabu(ts) = length(tabu_list(ts))

"""
    _insert_tabu!(s::S, x, tabu_time) where S <: Union{_State, AbstractSolver}
Insert the bariable `x` as tabu for `tabu_time`.
"""
insert_tabu!(ts, x, ::Val{:tabu}) = insert!(tabu_list(ts), x, max(1, tenure(ts, :tabu)))
insert_tabu!(ts::KeenTabu, x, kind::Symbol) = insert_tabu!(ts, x, Val(kind))
insert_tabu!(ts::WeakTabu, x, kind) = insert!(tabu_list(ts), x, max(1, tenure(ts, kind)))
insert_tabu!(ts, x, kind) = nothing


"""
    _decay_tabu!(s::S) where S <: Union{_State, AbstractSolver}
Decay the tabu list.
"""
function decay_tabu!(ts)
    foreach(
        ((x, tabu),) -> tabu == 1 ? delete_tabu!(ts, x) : decrease_tabu!(ts, x),
        pairs(tabu_list(ts))
    )
end