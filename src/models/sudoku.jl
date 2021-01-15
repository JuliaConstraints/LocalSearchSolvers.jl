function sudoku(n::Int; start::Dictionary{Int,Int}=Dictionary{Int,Int}())
    N = n^2
    d = domain(1:N)

    m = Model(;kind=:sudoku)

    # Add variables
    foreach(_ -> variable!(m, d), 1:(N^2))

    err = (x; param=nothing, dom_size=N) -> error_f(
        usual_constraints[:all_different])(x; param=param, dom_size=dom_size
    )

    # Add constraints: line, columns; blocks
    foreach(i -> constraint!(m, err, (i * N + 1):((i + 1) * N)), 0:(N - 1))
    foreach(i -> constraint!(m, err, [j * N + i for j in 0:(N - 1)]), 1:N)

    for i in 0:(n - 1)
        for j in 0:(n - 1)
            vars = Vector{Int}()
            for k in 1:n
                for l in 0:(n - 1)
                    push!(vars, (j * n + l) * N + i * n + k)
                end
            end
            constraint!(m, err, vars)
        end
    end

    # TODO: Insert starting values (assuming they are correct)
    # foreach(((k,v),) -> , pairs(start))

    return m
end

@doc raw"""
```julia
mutable struct Sudoku{T <: Integer} <: AbstractMatrix{T}
```
A `struct` for Sudokus, which is a subtype of `AbstractMatrix`.
---
```julia
Sudoku(A::AbstractMatrix{T})
Sudoku(::Type{T}, n::Int) # fill in blank sudoku of type T
Sudoku(n::Int) # fill in blank sudoku of type Int
Sudoku(::Type{T}) # fill in "standard" 9×9 sudoku of type T
Sudoku() # fill in "standard" 9×9 sudoku of type Int
Sudoku(n::Int, P::Pair{Tuple{Int, Int}, T}...) where {T <: Integer} # construct a sudoku given pairs of coordinates and values
Sudoku(P::Pair{Tuple{Int, Int}, T}...) # again, default to 9×9 sudoku, constructing given pairs
```
Constructor functions for the `Sudoku` `struct`.
"""
mutable struct Sudoku{T <: Integer} <: AbstractMatrix{T}
    A::AbstractMatrix{T} where {T <: Integer}

    function Sudoku(A::AbstractMatrix{T}) where {T <: Integer}
        size(A, 1) == size(A, 2) || throw(error("Sodokus must be square; received matrix of size $(size(A, 1))×$(size(A, 2))."))
        isequal(sqrt(size(A, 1)), isqrt(size(A, 1))) || throw(error("Sudokus must be able to split into equal boxes (e.g., a 9×9 Sudoku has three 3×3 squares).  Size given is $(size(A, 1))×$(size(A, 2))."))
        new{T}(A)
    end
    # fill in blank sudoku if needed
    Sudoku(::Type{T}, n::Int) where {T <: Integer} = new{T}(fill(zero(T), n, n))
    Sudoku(n::Int) = new{Int}(Sudoku(Int, n))
    # Use "standard" 9×9 if no size provided
    Sudoku(::Type{T}) where {T <: Integer} = new{T}(Sudoku(T, 9))
    Sudoku() = new{Int}(Sudoku(9))
    # Construct a sudoku given coordinates and values
    function Sudoku(n::Int, P::Pair{Tuple{Int,Int},T}...) where {T <: Integer}
        A = zeros(T, n, n)
        for (i, v) in P
            A[i...] = v
        end
        new{T}(A)
    end
    # again, default to 9×9
    Sudoku(P::Pair{Tuple{Int,Int},T}...) where {T <: Integer} = new{T}(Sudoku(9, P...))
end

# abstract array interface for Sudoku struct
Base.size(S::Sudoku) = size(S.A)
Base.getindex(S::Sudoku, i::Int) = getindex(S.A, i)
Base.getindex(S::Sudoku, I::Vararg{Int,N}) where {N} = getindex(S.A, I...)
Base.setindex!(S::Sudoku, v, i::Int) = setindex!(S.A, v, i)
Base.setindex!(S::Sudoku, v, I::Vararg{Int,N}) where {N} = setindex!(S.A, v, I...)

const up_right_corner = '┐'
const up_left_corner = '┌'
const bottom_left_corner = '└'
const bottom_right_corner = '┘'
const up_intersection = '┬'
const left_intersection = '├'
const right_intersection = '┤'
const middle_intersection = '┼'
const bottom_intersection = '┴'
const column = '│'
const row = '─'
const blank = '⋅'  # this is the character used for 0s in a Sudoku puzzle

function _format_val(a::Integer)
    return iszero(a) ? blank : string(a)
end

function _format_line_segment(r::AbstractVector, col_pos::Int, M::AbstractMatrix)
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

    return line * ' ' * column
end

function _format_line(r::AbstractVector, M::AbstractMatrix)
    sep_length = isqrt(length(r))

    line = column
    for i in 1:sep_length
        abs_sep_pos = sep_length * i
        line *= _format_line_segment(r[(abs_sep_pos - sep_length + 1):abs_sep_pos], i - 1, M)
    end

    return line
end

function _get_sep_line(s::Int, pos_row::Int, M::AbstractMatrix)
    sep_length = isqrt(s)

    # deal with left-most edges
    sep_line = string()
    if pos_row == 1
        sep_line *= up_left_corner
    elseif mod(pos_row, sep_length) == 0
        if pos_row == s
            sep_line *= bottom_left_corner
        else
            sep_line *= left_intersection
        end
    end

    # rest of row seperator; TODO: make less convoluted.  ATM it works, but I think it can be simplified.
    for pos_col in 1:s
        sep_line *= repeat(row, maximum((ndigits(i) for i in M[:, pos_col])) + 1)
        if mod(pos_col, sep_length) == 0
            sep_line *= row
            if pos_col == s
                if pos_row == 1
                    sep_line *= up_right_corner
                elseif pos_row == s
                    sep_line *= bottom_right_corner
                else
                    sep_line *= right_intersection
                end
            elseif pos_row == 1
                sep_line *= up_intersection
            elseif pos_row == s
                sep_line *= bottom_intersection
            else
                sep_line *= middle_intersection
            end
        end
    end

    return sep_line
end

@doc raw"""
```julia
display(io::IO, S::Sudoku)
display(S::Sudoku) # default to stdout
```
Displays an ``n\times n`` Sudoku.
"""
function Base.display(io::IO, S::Sudoku)
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
# fall back on stdout
Base.display(S::Sudoku) = display(stdout, S)


### Examples

const sudoku1 = [
    9  3  0  0  0  0  0  4  0
    0  0  0  0  4  2  0  9  0
    8  0  0  1  9  6  7  0  0
    0  0  0  4  7  0  0  0  0
    0  2  0  0  0  0  0  6  0
    0  0  0  0  2  3  0  0  0
    0  0  8  5  3  1  0  0  2
    0  9  0  2  8  0  0  0  0
    0  7  0  0  0  0  0  5  3
];

const sudoku2 = [
    0  0  9  0  1  0  0  6  0
    0  0  0  0  6  7  0  0  3
    0  3  5  0  0  0  0  0  0
    3  0  0  0  0  2  0  0  0
    5  1  7  0  0  0  2  3  4
    0  0  0  3  0  0  0  0  7
    0  0  0  0  0  0  9  1  0
    1  0  0  6  8  0  0  0  0
    0  7  0  0  3  0  5  0  0
];

const sudoku3 = [
    0  3  7  8  6  0  0  4  0
    0  0  6  0  0  7  0  0  0
    0  2  0  0  3  0  0  0  6
    0  8  0  2  0  0  0  0  0
    9  0  0  0  0  0  0  0  1
    0  0  0  0  0  6  0  9  0
    5  0  0  0  7  0  0  3  0
    0  0  0  3  0  0  8  0  0
    0  1  0  0  8  4  2  6  0
];

const sudoku_small = [
    2  0  0  3
    0  0  0  1
    1  0  0  0
    3  0  0  2
];

const sudoku_large = [
    1   0   0   2   3   4   0   0  12   0   6   0   0   0   7   0
    0   0   8   0   0   0   7   0   0   3   0   0   9  10   6  11
    0  12   0   0  10   0   0   1   0  13   0  11   0   0  14   0
    3   0   0  15   2   0   0  14   0   0   0   9   0   0  12   0
   13   0   0   0   8   0   0  10   0  12   2   0   1  15   0   0
    0  11   7   6   0   0   0  16   0   0   0  15   0   0   5  13
    0   0   0  10   0   5  15   0   0   4   0   8   0   0  11   0
   16   0   0   5   9  12   0   0   1   0   0   0   0   0   8   0
    0   2   0   0   0   0   0  13   0   0  12   5   8   0   0   3
    0  13   0   0  15   0   3   0   0  14   8   0  16   0   0   0
    5   8   0   0   1   0   0   0   2   0   0   0  13   9  15   0
    0   0  12   4   0   6  16   0  13   0   0   7   0   0   0   5
    0   3   0   0  12   0   0   0   6   0   0   4  11   0   0  16
    0   7   0   0  16   0   5   0  14   0   0   1   0   0   2   0
   11   1  15   9   0   0  13   0   0   2   0   0   0  14   0   0
    0  14   0   0   0  11   0   2   0   0  13   3   5   0   0  12
];
