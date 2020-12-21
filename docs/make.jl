using LocalSearchSolvers
using Documenter

@info "Makeing documentation..."
makedocs(;
    modules=[LocalSearchSolvers],
    authors="Jean-François Baffier",
    repo="https://github.com/JuliaConstraints/LocalSearchSolvers.jl/blob/{commit}{path}#L{line}",
    sitename="LocalSearchSolvers.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", nothing) == "true",
        canonical="https://JuliaConstraints.github.io/LocalSearchSolvers.jl",
        assets = ["assets/favicon.ico"; "assets/github_buttons.js"; "assets/custom.css"],
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => [
            "Quick Start Guide" => "quickstart.md",
            "Variables" => "variables.md",
            "Constraints" => "constraints.md",
            "Objectives" => "objectives.md",
            "Problems" => "problems.md",
            "Solvers" => "solvers.md",
        ],
        "Domain Specific Languages" => [
            "JuMPish" => "jump.md",
            "MiniZinc" => "minizinc.md",
        ],
        "Library" => [
            "Public" => "public.md",
            "Internals" => "internals.md",
        ],
        "Constributing" => "contributing.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaConstraints/LocalSearchSolvers.jl.git",
    devbranch="main",
)
