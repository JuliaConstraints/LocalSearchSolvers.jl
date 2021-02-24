abstract type TabuStrategy end

struct KeenTabu <: TabuStrategy
    tabu_tenure::Int
end

struct WeakTabu <: TabuStrategy
    tabu_tenure::Int
    pick_tenure::Int
end

tenure(strategy, ::Val{:tabu}) = strategy.tabu_tenure
tenure(strategy::WeakTabu, ::Val{:pick}) = strategy.pick_tenure
tenure(::TabuStrategy, ::Val{:pick}) = zero(Int)
tenure(strategy, field) = tenure(strategy, Val(field))
