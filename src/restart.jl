function oeis(n, b, ::Val{:A082850})
    m = log(b,n+1)
    return isinteger(m) ? Int(m) : oeis(n - (b^floor(m) - 1), :A082850)
end

oeis(n, b, ::Val{:A182105}) = b^(oeis(n, :A082850)-1)

oeis(n, ref::Symbol, b = 2) = oeis(n, b, Val(ref))

mutable struct Restart{F <: Function}
    index::Int
    current::Int
    next::F

    Restart(seq) = new{typeof(seq)}(1, seq(1), seq)
end

current(r) = r.current

function next!(r)
    r.index += 1
    r.current = r.next(r.index)
    return r.current
end

restart(::Val{:universal}) = Restart(n -> oeis(n, :A182105))

restart(strategy::Symbol) = restart(Val(strategy))


