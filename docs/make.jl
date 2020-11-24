using LocalSearchSolvers
using Documenter

makedocs(;
    modules=[LocalSearchSolvers],
    authors="Jean-Francois Baffier",
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

deploydocs(;
    repo="github.com/azzaare/LocalSearchSolvers.jl.git",
    devbranch="main",
)
