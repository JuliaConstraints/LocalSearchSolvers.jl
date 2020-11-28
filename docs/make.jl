using LocalSearchSolvers
using Documenter

@info "Makeing documentation..."
makedocs(;
    modules=[LocalSearchSolvers],
    authors="Jean-François Baffier",
    repo="https://github.com/Azzaare/LocalSearchSolvers.jl/blob/{commit}{path}#L{line}",
    sitename="LocalSearchSolvers.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Azzaare.github.io/LocalSearchSolvers.jl",
        assets = ["assets/favicon.ico"; "assets/github_buttons.js"; "assets/custom.css"],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Azzaare/LocalSearchSolvers.jl.git",
    devbranch="main",
)