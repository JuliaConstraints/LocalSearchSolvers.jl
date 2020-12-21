var documenterSearchIndex = {"docs":
[{"location":"quickstart/#Quick-Start-Guide","page":"Quick Start Guide","title":"Quick Start Guide","text":"","category":"section"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"This section introduce the main concepts of LocalSearchSolvers.jl. We model both a satisfaction and an optimization version of the Golomb Ruler problem.","category":"page"},{"location":"quickstart/#Golomb-Ruler","page":"Quick Start Guide","title":"Golomb Ruler","text":"","category":"section"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"From Wikipedia's English page.","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"In mathematics, a Golomb ruler is a set of marks at integer positions along an imaginary ruler such that no two pairs of marks are the same distance apart. The number of marks on the ruler is its order, and the largest distance between two of its marks is its length. Translation and reflection of a Golomb ruler are considered trivial, so the smallest mark is customarily put at 0 and the next mark at the smaller of its two possible values.","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"(Image: )","category":"page"},{"location":"quickstart/#Satisfaction-version","page":"Quick Start Guide","title":"Satisfaction version","text":"","category":"section"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"Given a number of marks n and a ruler length L, we can model our problem in Julia as easily as follows. First create an empty problem.","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"p = Problem()","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"Then add n variables with domain d.","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"d = domain(0:L)\nforeach(_ -> variable!(p, d), 1:n)","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"Finally add the following constraints,","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"all marks have a different value\nfirst mark has value 0\nfinally, no two pairs of marks are the same distance appart","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"constraint!(p, c_all_different, 1:n)\nconstraint!(p, x -> c_all_equal_param(x; param = 0), 1:1)\nfor i in 1:(n - 1), j in (i + 1):n, k in i:(n - 1), l in (k + 1):n\n    (i, j) < (k, l) || continue\n    constraint!(p, c_dist_different, [i, j, k, l])\nend","category":"page"},{"location":"quickstart/#Optimization-version","page":"Quick Start Guide","title":"Optimization version","text":"","category":"section"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"A Golomb ruler can be either optimally dense (maximal m for a given L) or optimally short (minimal L for a given n). Until LocalSearchSolvers.jl implements dynamic problems, only optimal shortness is provided.","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"The model objective is then to minimize the maximum distance between the two extrema marks in the ruler.","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"objective!(p, o_dist_extrema)","category":"page"},{"location":"quickstart/#Ruling-the-solver","page":"Quick Start Guide","title":"Ruling the solver","text":"","category":"section"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"For either version, the solver is built and run in a similar way. Please note that the satisfaction one will stop if a solution is found. The other will run until the maximum number of iteration is reached.","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"s = Solver(p)\nsolve!(s)","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"And finally retrieve the (best-known) solution info. (TODO: make it julian and clean)","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"@info \"Results golomb!\"\n@info \"Values: $(s.state.values)\"\n@info \"Sol (val): $(s.state.best_solution_value)\"\n@info \"Sol (vals): $(!isnothing(s.state.best_solution_value) ? s.state.best_solution : nothing)\"","category":"page"},{"location":"quickstart/","page":"Quick Start Guide","title":"Quick Start Guide","text":"Please note, that the Golomb Ruler is already implemented in the package as golomb(n::Int, L::Int=n^2). An hand-made printing function is also there: TODO:.","category":"page"},{"location":"public/","page":"Public","title":"Public","text":"","category":"page"},{"location":"public/","page":"Public","title":"Public","text":"Modules = [LocalSearchSolvers]","category":"page"},{"location":"public/#LocalSearchSolvers.Solver-Union{Tuple{Problem}, Tuple{T}, Tuple{Problem,Dict{Symbol,Any}}} where T<:Number","page":"Public","title":"LocalSearchSolvers.Solver","text":"Solver{T}(p::Problem; values::Dictionary{Int,T}=Dictionary{Int,T}()) where T <: Number\nSolver{T}(;\n    variables::Dictionary{Int,Variable}=Dictionary{Int,Variable}(),\n    constraints::Dictionary{Int,Constraint}=Dictionary{Int,Constraint}(),\n    objectives::Dictionary{Int,Objective}=Dictionary{Int,Objective}(),\n    values::Dictionary{Int,T}=Dictionary{Int,T}(),\n) where T <: Number\n\nConstructor for a solver. Optional starting values can be provided.\n\n# Model a sudoku problem of size 4×4\np = sudoku(2)\n\n# Create a solver instance with variables taking integral values\ns = Solver{Int}(p)\n\n# Solver with an empty problem to be filled later and expected Float64 values\ns = Solver{Float64}()\n\n# Construct a solver from a sets of constraints, objectives, and variables.\ns = Solver{Int}(\n    variables = get_constraints(p),\n    constraints = get_constraints(p),\n    objectives = get_objectives(p)\n)\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.c_all_different-Union{Tuple{Vararg{T,N} where N}, Tuple{T}} where T<:Number","page":"Public","title":"LocalSearchSolvers.c_all_different","text":"all_different(x::Int...)\n\nGlobal constraint ensuring that all the values of x are unique.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.c_all_equal-Union{Tuple{Vararg{T,N} where N}, Tuple{T}} where T<:Number","page":"Public","title":"LocalSearchSolvers.c_all_equal","text":"all_equal(x::Int...; param::T)\nall_equal(x::Int...)\n\nGlobal constraint ensuring that all the values of x are all_equal (to param if given).\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.c_dist_different-Union{Tuple{T}, NTuple{4,T}} where T<:Number","page":"Public","title":"LocalSearchSolvers.c_dist_different","text":"dist_different(i::T, j::T, k::T, l::T) where {T <: Number}\n\nLocal constraint ensuring that |i - j| ≠ |k - l|.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.c_ordered-Tuple{Vararg{Int64,N} where N}","page":"Public","title":"LocalSearchSolvers.c_ordered","text":"ordered(x::Int...)\n\nGlobal constraint ensuring that all the values of x are ordered.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.constraint-Union{Tuple{F}, Tuple{T}, Tuple{F,AbstractArray{Int64,1},AbstractArray{T,1}}} where F<:Function where T<:Number","page":"Public","title":"LocalSearchSolvers.constraint","text":"constraint(f::F, inds::Vector{Int}, values::Vector{T}) where {F <: Function,T <: Number}\nconstraint(f::F, inds::Vector{Int}, vars::Dictionary{Int,Variable}) where F <: Function\n\nTest the validity of f over a set of values or draw them from a set of variables vars. Return a constraint if the test is succesful, otherwise raise an error.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.describe-Tuple{Problem}","page":"Public","title":"LocalSearchSolvers.describe","text":"describe(p::Problem)\ndescribe(s::AbstractSolver)\n\nDescribe the model of either a Problem or a Solver.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.domain-Union{Tuple{AbstractArray{T,1}}, Tuple{T}} where T<:Number","page":"Public","title":"LocalSearchSolvers.domain","text":"domain(values::AbstractVector; type = :set)\n\nDiscrete domain constructor. The type keyword can be set to :set (default) or :indices.\n\nd1 = domain([1,2,3,4], type = :indices)\nd2 = domain([53.69, 89.2, 0.12])\nd3 = domain([2//3, 89//123])\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.is_sat-Tuple{Problem}","page":"Public","title":"LocalSearchSolvers.is_sat","text":"is_sat(p::Problem)\n\nReturn true if p is a satisfaction problem.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.is_specialized-Tuple{Problem}","page":"Public","title":"LocalSearchSolvers.is_specialized","text":"is_specialized(p::Problem)\nis_specialized(s::Solver)\n\nReturn true if the problem is already specialized.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.o_dist_extrema-Union{Tuple{Vararg{T,N} where N}, Tuple{T}} where T<:Number","page":"Public","title":"LocalSearchSolvers.o_dist_extrema","text":"dist_extrema(values::T...) where {T <: Number}\n\nComputes the distance between extrema in an ordered set.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.solve!-Tuple{Solver}","page":"Public","title":"LocalSearchSolvers.solve!","text":"solve!(s::Solver{T}; max_iteration=1000, verbose::Bool=false) where {T <: Real}\n\nRun the solver until a solution is found or max_iteration is reached. verbose=true will print out details of the run.\n\n# Simply run the solver with default max_iteration\nsolve!(s)\n\n# Run indefinitely the solver with verbose behavior.\nsolve!(s, max_iteration = Inf, verbose = true)\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.specialize-Tuple{Problem}","page":"Public","title":"LocalSearchSolvers.specialize","text":"specialize(p::Problem)\nspecialize(s::Solver)\n\nSpecialize the structure of a problem to avoid dynamic type attribution at runtime.\n\n\n\n\n\n","category":"method"},{"location":"public/#LocalSearchSolvers.variable-Tuple{LocalSearchSolvers.AbstractDomain,AbstractString}","page":"Public","title":"LocalSearchSolvers.variable","text":"variable(values::AbstractVector{T}, name::AbstractString; domain = :set) where T <: Number\nvariable(domain::AbstractDomain, name::AbstractString) where D <: AbstractDomain\n\nConstruct a variable with discrete domain. See the domain method for other options.\n\nd = domain([1,2,3,4], types = :indices)\nx1 = variable(d, \"x1\")\nx2 = variable([-89,56,28], \"x2\", domain = :indices)\n\n\n\n\n\n","category":"method"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = LocalSearchSolvers","category":"page"},{"location":"#Constraint-Based-Local-Search-(CBLS)","page":"Home","title":"Constraint-Based Local Search (CBLS)","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"LocalSearchSolvers.jl proposes sets of technical components of Constraint-Based Local Search solvers and combine them in various ways.","category":"page"},{"location":"","page":"Home","title":"Home","text":"<!– TODO: what is a CBLS solver etc. –>","category":"page"}]
}
