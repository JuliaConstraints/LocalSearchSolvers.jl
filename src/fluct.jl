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

function copy_to!(fluct, cons, vars)
    foreach(k -> set!(fluct.cons, k, cons[k]), cons)
    foreach(k -> set!(fluct.vars, k, vars[k]), vars)
end

function copy_from!(fluct, cons, vars)
    foreach(k -> set!(cons, k, fluct.cons[k]), cons)
    foreach(k -> set!(vars, k, fluct.vars[k]), vars)
end