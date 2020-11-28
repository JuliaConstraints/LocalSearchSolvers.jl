struct Objective{F <: Function}
    name::String
    f::F
end

"""
    objective(f::F, name::String) where {F <: Function}
Construct an objective with a function `f` that should be applied to a set of variables.

Practical examples will come with the implementation of the optimisation part of the module.
"""
# TODO: make a verification at construction
function objective(f::F, name::String) where {F <: Function}
    Objective(name, f)
end
