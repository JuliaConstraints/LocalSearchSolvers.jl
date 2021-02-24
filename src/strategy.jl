struct MetaStrategy{RS <: RestartStrategy}
    restart::RS
end

function MetaStrategy(;
    restart = restart(:universal),
)
    return MetaStrategy(restart)
end

@forward MetaStrategy.restart check_restart!