mutable struct SolverOptions
    iteration::Union{Int, Float64}
    specialize::Bool
    threads::Int
    verbose::Bool # TODO: make it an enum
end

function SolverOptions(;
    iteration = 1000,
    specialize = true, # TODO conditional on dynamic/static
    threads = typemax(0),
    verbose = false,
)
    SolverOptions(;
        iteration = iteration,
        specialize = specialize,
        threads = threads,
        verbose = verbose,
    )

end
