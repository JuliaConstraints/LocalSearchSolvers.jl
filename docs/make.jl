using LocalSearchSolvers
using Documenter

makedocs(;
    modules=[LocalSearchSolvers],
    authors="Jean-François Baffier",
    repo="https://github.com/azzaare/LocalSearchSolvers.jl/blob/{commit}{path}#L{line}",
    sitename="LocalSearchSolvers.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://azzaare.github.io/LocalSearchSolvers.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
