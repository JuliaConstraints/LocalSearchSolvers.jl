"""
    Objective{F <: Function}
A structure to handle objectives in a solver.
```
struct Objective{F <: Function}
    name::String
    f::F
end
````
"""
struct Objective{F <: Function} <: FunctionContainer
    name::String
    f::F
end

"""
    Objective(F, o::Objective{F2}) where {F2 <: Function}
Constructor used in specializing a solver. Should never be called externally.
"""
Objective(F, o::Objective{F2}) where {F2 <: Function} = Objective{F}(o.name, o.f)

"""
    objective(func, name)
Construct an objective with a function `func` that should be applied to a collection of variables.
"""
objective(func, name = "Objective (generic name)") = Objective(name, func)

"""
    apply(o::Objective, x)

Apply the objective function `o` to the collection of variables `x`.
"""

@testitem "Objective" begin
    o = objective(x -> x[1] + x[2])
    @test LocalSearchSolvers.apply(o, [1, 2]) == 3
end
