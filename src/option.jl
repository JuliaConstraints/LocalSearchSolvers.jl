const print_levels = Dict(
    :silent => 0,
    :minimal => 1,
    :partial => 2,
    :verbose => 3,
)

mutable struct SolverOptions
    iteration::Union{Int,Float64}
    print_level::Symbol
    specialize::Bool
    threads::Int
    time_limit::Time # nanoseconds
end

function SolverOptions(;
    iteration=1000,
    print_level=1,
    specialize=true, # TODO conditional on dynamic/static
    threads=typemax(0),
)
    SolverOptions(;
        iteration=iteration,
        print_level=print_level,
        specialize=specialize,
        threads=threads,
        time_limit=time_limit
    )

end
