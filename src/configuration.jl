struct Configuration{T <: Number}
    solution::Bool
    value::Float64
    values::Dictionary{Int, T}
end

is_solution(c) = c.solution
value(c) = c.value
error(c) = is_solution(c) ? 0.0 : get_value(c)