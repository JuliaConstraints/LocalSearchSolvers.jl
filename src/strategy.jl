struct MetaStrategy{RS <: RestartStrategy, TS <: TabuStrategy}
    restart::RS
    tabu::TS
end

function MetaStrategy(;
    restart = restart(:universal),
    tabu = tabu(10),
)
    return MetaStrategy(restart, tabu)
end

# forwards from RestartStrategy
@forward MetaStrategy.restart check_restart!

# forwards from TabuStrategy
@forward MetaStrategy.tabu decrease_tabu!, delete_tabu!, decay_tabu!
@forward MetaStrategy.tabu length_tabu, insert_tabu!, empty_tabu!, tabu_list