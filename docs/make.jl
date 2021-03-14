using LocalSearchSolvers
using ConstraintDomains
using CompositionalNetworks
using Constraints
using Documenter

@info "Makeing documentation..."
makedocs(;
    modules=[LocalSearchSolvers, ConstraintDomains, CompositionalNetworks, Constraints],
    expandfirst = ["variables.md", "constraints.md", "objectives.md", "solving.md"],
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
            "Solving" => "solving.md",
        ],
        "Examples" => [
            "Sudoku" => "sudoku.md",
            "Golomb ruler" => "golomb.md",
            "Mincut" => "mincut.md",
        ],
        "Dependencies" => [
            "ConstraintDomains.jl" => "domain.md",
            "Constraints.jl" => "d_constraint.md",
            "CompositionalNetworks.jl" => "icn.md",
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
