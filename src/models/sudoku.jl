"""
    sudoku(n; start= Dictionary{Int, Int}())

Create a model for the sudoku problem of domain `1:n²` with optional starting values.
"""
function sudoku(n; start=Dictionary{Int,Int}())
    N = n^2
    d = domain(1:N)

    m = Model(;kind=:sudoku)

    # Add variables
    if isempty(start)
        foreach(_ -> variable!(m, d), 1:(N^2))
    else
        foreach(((x, v),) -> variable!(m, 1 ≤ v ≤ N ? domain(v:v) : d), pairs(start))
    end


    e1 = (x; param=nothing, dom_size=N) -> error_f(
        usual_constraints[:all_different])(x; param=param, dom_size=dom_size
    )
    e2 = (x; param=nothing, dom_size=N) -> error_f(
        usual_constraints[:all_equal_param])(x; param=param, dom_size=dom_size
    )

    # Add constraints: line, columns; blocks
    foreach(i -> constraint!(m, e1, (i * N + 1):((i + 1) * N)), 0:(N - 1))
    foreach(i -> constraint!(m, e1, [j * N + i for j in 0:(N - 1)]), 1:N)

    for i in 0:(n - 1)
        for j in 0:(n - 1)
            vars = Vector{Int}()
            for k in 1:n
                for l in 0:(n - 1)
                    push!(vars, (j * n + l) * N + i * n + k)
                end
            end
            constraint!(m, e1, vars)
        end
    end

    return m
end

@doc raw"""
```julia
mutable struct SudokuInstance{T <: Integer} <: AbstractMatrix{T}
```
A `struct` for SudokuInstances, which is a subtype of `AbstractMatrix`.
---
```julia
SudokuInstance(A::AbstractMatrix{T})
SudokuInstance(::Type{T}, n::Int) # fill in blank sudoku of type T
SudokuInstance(n::Int) # fill in blank sudoku of type Int
SudokuInstance(::Type{T}) # fill in "standard" 9×9 sudoku of type T
SudokuInstance() # fill in "standard" 9×9 sudoku of type Int
SudokuInstance(n::Int, P::Pair{Tuple{Int, Int}, T}...) where {T <: Integer} # construct a sudoku given pairs of coordinates and values
SudokuInstance(P::Pair{Tuple{Int, Int}, T}...) # again, default to 9×9 sudoku, constructing given pairs
```
Constructor functions for the `SudokuInstance` `struct`.
"""
mutable struct SudokuInstance{T <: Integer} <: AbstractMatrix{T}
    A::AbstractMatrix{T} where {T <: Integer}

    function SudokuInstance(A::AbstractMatrix{T}) where {T <: Integer}
        size(A, 1) == size(A, 2) || throw(error("Sodokus must be square; received matrix of size $(size(A, 1))×$(size(A, 2))."))
        isequal(sqrt(size(A, 1)), isqrt(size(A, 1))) || throw(error("SudokuInstances must be able to split into equal boxes (e.g., a 9×9 SudokuInstance has three 3×3 squares).  Size given is $(size(A, 1))×$(size(A, 2))."))
        new{T}(A)
    end
    # fill in blank sudoku if needed
    SudokuInstance(::Type{T}, n::Int) where {T <: Integer} = new{T}(fill(zero(T), n, n))
    SudokuInstance(n::Int) = new{Int}(SudokuInstance(Int, n))
    # Use "standard" 9×9 if no size provided
    SudokuInstance(::Type{T}) where {T <: Integer} = new{T}(SudokuInstance(T, 9))
    SudokuInstance() = new{Int}(SudokuInstance(9))
    # Construct a sudoku given coordinates and values
    function SudokuInstance(n::Int, P::Pair{Tuple{Int,Int},T}...) where {T <: Integer}
        A = zeros(T, n, n)
        for (i, v) in P
            A[i...] = v
        end
        new{T}(A)
    end
    # again, default to 9×9
    SudokuInstance(P::Pair{Tuple{Int,Int},T}...) where {T <: Integer} = new{T}(SudokuInstance(9, P...))
end

"""
    SudokuInstance(X::Dictionary)

Construct a `SudokuInstance` with the values `X` of a solver as input.
"""
function SudokuInstance(X::Dictionary)
    n = isqrt(length(X))
    A = zeros(Int, n, n)
    for (k,v) in enumerate(Base.Iterators.partition(X, n))
        A[k,:] = v
    end
    return SudokuInstance(A)
end

# # abstract array interface for SudokuInstance struct
"""
    Base.size(S::SudokuInstance)

Extends `Base.size` for `SudokuInstance`.
"""
Base.size(S::SudokuInstance) = size(S.A)

"""
    Base.getindex(S::SudokuInstance, i::Int)
    Base.getindex(S::SudokuInstance, I::Vararg{Int,N}) where {N}

Extends `Base.getindex` for `SudokuInstance`.
"""
Base.getindex(S::SudokuInstance, i::Int) = getindex(S.A, i)
Base.getindex(S::SudokuInstance, I::Vararg{Int,N}) where {N} = getindex(S.A, I...)

"""
    Base.setindex!(S::SudokuInstance, v, i::Int)
    Base.setindex!(S::SudokuInstance, v, I::Vararg{Int,N})

Extends `Base.setindex!` for `SudokuInstance`.
"""
Base.setindex!(S::SudokuInstance, v, i) = setindex!(S.A, v, i)
Base.setindex!(S::SudokuInstance, v, I::Vararg) = setindex!(S.A, v, I...)

const _rules = Dict(
    :up_right_corner => '┐',
    :up_left_corner => '┌',
    :bottom_left_corner => '└',
    :bottom_right_corner => '┘',
    :up_intersection => '┬',
    :left_intersection => '├',
    :right_intersection => '┤',
    :middle_intersection => '┼',
    :bottom_intersection => '┴',
    :column => '│',
    :row => '─',
    :blank => '⋅',  # this is the character used for 0s in a SudokuInstance puzzle
)

"""
    _format_val(a)

Format an integer `a` into a string for SudokuInstance.
"""
_format_val(a) = iszero(a) ? _rules[:blank] : string(a)

"""
    _format_line_segment(r, col_pos, M)

Format line segment of a sudoku grid.
"""
function _format_line_segment(r, col_pos, M)
    sep_length = length(r)

    line = string()
    for k in axes(r, 1)
        n_spaces = 1
        Δ = maximum((ndigits(i) for i in M[:, (col_pos * sep_length) + k])) - ndigits(r[k])
        if Δ ≥ 0
            n_spaces = Δ + 1
        end
        line *= repeat(' ', n_spaces) * _format_val(r[k])
    end

    return line * ' ' * _rules[:column]
end

"""
    _format_line(r, M)

Format line of a sudoku grid.
"""
function _format_line(r, M)
    sep_length = isqrt(length(r))

    line = _rules[:column]
    for i in 1:sep_length
        abs_sep_pos = sep_length * i
        line *= _format_line_segment(r[(abs_sep_pos - sep_length + 1):abs_sep_pos], i - 1, M)
    end

    return line
end

"""
    _get_sep_line(s, pos_row, M)

Return a line separator.
"""
function _get_sep_line(s, pos_row, M)
    sep_length = isqrt(s)

    # deal with left-most edges
    sep_line = string()
    if pos_row == 1
        sep_line *= _rules[:up_left_corner]
    elseif mod(pos_row, sep_length) == 0
        if pos_row == s
            sep_line *= _rules[:bottom_left_corner]
        else
            sep_line *= _rules[:left_intersection]
        end
    end

    # rest of row seperator; TODO: make less convoluted.  ATM it works, but I think it can be simplified.
    for pos_col in 1:s
        sep_line *= repeat(_rules[:row], maximum((ndigits(i) for i in M[:, pos_col])) + 1)
        if mod(pos_col, sep_length) == 0
            sep_line *= _rules[:row]
            if pos_col == s
                if pos_row == 1
                    sep_line *= _rules[:up_right_corner]
                elseif pos_row == s
                    sep_line *= _rules[:bottom_right_corner]
                else
                    sep_line *= _rules[:right_intersection]
                end
            elseif pos_row == 1
                sep_line *= _rules[:up_intersection]
            elseif pos_row == s
                sep_line *= _rules[:bottom_intersection]
            else
                sep_line *= _rules[:middle_intersection]
            end
        end
    end

    return sep_line
end

@doc raw"""
```julia
display(io::IO, S::SudokuInstance)
display(S::SudokuInstance) # default to stdout
```
Displays an ``n\times n`` SudokuInstance.
"""
function Base.display(io, S::SudokuInstance)
    sep_length = isqrt(size(S, 1))
    max_n_digits = maximum((ndigits(i) for i in S))

    println(io, _get_sep_line(size(S, 1), 1, S))
    for (i, r) in enumerate(eachrow(S))
        println(io, _format_line(r, S))
        if iszero(mod(i, sep_length))
            println(io, _get_sep_line(size(S, 1), i, S))
        end
    end

    return nothing
end

"""
    Base.display(S::SudokuInstance)

Extends `Base.display` to `SudokuInstance`.
"""
Base.display(S::SudokuInstance) = display(stdout, S)

"""
    Base.display(X::Dictionary)

Extends `Base.display` to a sudoku configuration.
"""
Base.display(X::Dictionary) = display(SudokuInstance(X))
