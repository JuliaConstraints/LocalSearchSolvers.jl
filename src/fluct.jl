struct Fluct
    cons::Dictionary{Int, Float64}
    vars::Dictionary{Int, Float64}
    Fluct(cons, vars) = new(zeros(cons), zeros(vars))
end



function reset!(fluct)
    zeros! = d -> foreach(k -> set!(d, k, 0.0), keys(d))
    zeros!(fluct.cons)
    zeros!(fluct.vars)
end

function copy_to!(fluct, cons, vars)
    foreach(k -> set!(fluct.cons, k, cons[k]), keys(cons))
    foreach(k -> set!(fluct.vars, k, vars[k]), keys(vars))
end

function copy_from!(fluct, cons, vars)
    foreach(k -> set!(cons, k, fluct.cons[k]), keys(cons))
    foreach(k -> set!(vars, k, fluct.vars[k]), keys(vars))
end
