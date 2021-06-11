struct Fluct
    cons::Dictionary{Int, Float64}
    vars::Dictionary{Int, Float64}
end

Fluct(cons, vars) = Fluct(zeros(cons), zeros(vars))

function reset!(fluct)
    zeros! = d -> foreach(k -> set!(d, k, 0.0), keys(d))
    zeros!(fluct.cons)
    zeros!(fluct.vars)
end
