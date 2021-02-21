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
struct Objective{F <: Function}
    name::String
    f::F
end

"""
    Objective(F, o::Objective{F2}) where {F2 <: Function}
Constructor used in specializing a solver. Should never be called externally.
"""
function Objective(F, o::Objective{F2}) where {F2 <: Function}
    return Objective{F}(o.name, o.f)
end

"""
    objective(func, name)
Construct an objective with a function `func` that should be applied to a collection of variables.
"""
function objective(func, name)
    Objective(name, func)
end