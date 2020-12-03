abstract type AbstractObjective end

struct _Objective{F <: Function} <: AbstractObjective
    name::String
    f::F
end

struct Objective <: AbstractObjective
    name::String
    f::Function
end

"""
    objective(f::Function, name::AbstractString)
Construct an objective with a function `f` that should be applied to a set of variables.

Practical examples will come with the implementation of the optimisation part of the module.
"""
# TODO: make a verification at construction
function objective(f::Function, name::AbstractString)
    Objective(name, f)
end
