const Verbose = LogLevel(-500)
const State = LogLevel(500)

function show(io::IO, level::LogLevel)
    level == Verbose ? print(io, "Verbose") :    
    level == State ? print(io, "State") : show(io, level)
end

macro verbose(exs...) :(@info $(exs...)) end
macro state(exs...) :(@logmsg State $(exs...)) end
