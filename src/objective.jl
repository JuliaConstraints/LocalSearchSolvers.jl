struct Objective{F <: Function}
    name::String
    f::F
end

# TODO: make a verification at construction
function objective(f::F, name::String) where {F <: Function}
    Objective(name, f)
end
