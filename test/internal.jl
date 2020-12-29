## test domains
d1 = domain([4,3,2,1])
d2 = domain([4,3,2,1]; type=:indices)
domains = Dictionary(1:2, [d1, d2])

# get
@test LocalSearchSolvers._get(d2, 2) == 3
for d in domains
    # constructors and ∈
    for x in [1,2,3,4]
        @test x ∈ d
    end
    # length
    @test LocalSearchSolvers._length(d) == 4
    # draw and ∈
    @test LocalSearchSolvers._draw(d) ∈ d
    # add!
    LocalSearchSolvers._add!(d, 5)
    @test 5 ∈ d
    # delete!
    LocalSearchSolvers._delete!(d, 5)
    @test 5 ∉ d
end


## test variables
x1 = variable([4,3,2,1], "x1")
x2 = variable(d2, "x2")
vars = Dictionary{Int, Variable}(1:2, [x1, x2])

@test LocalSearchSolvers._get(x2, 2) == 3
for x in vars
    # add and delete from constraint
    LocalSearchSolvers._add_to_constraint!(x, 1)
    LocalSearchSolvers._add_to_constraint!(x, 2)
    LocalSearchSolvers._delete_from_constraint!(x, 2)
    @test x ∈ 1
    @test x ∉ 2
    @test LocalSearchSolvers._constriction(x) == 1
    @test LocalSearchSolvers._length(x) == 4
    for y in [1,2,3,4]
        @test y ∈ x
    end
    @test LocalSearchSolvers._draw(x) ∈ x
    LocalSearchSolvers._add!(x, 5)
    @test 5 ∈ x
    LocalSearchSolvers._delete!(x, 5)
    @test 5 ∉ x
end

## test constraint
values = [1, 2, 3]
inds = [1, 2]
err = error_f(usual_constraints[:all_different])
c1 = constraint(err, inds, values)
c2 = constraint(err, inds, vars)
cons = Dictionary{Int, Constraint}(1:2, [c1, c2])

for c in cons
    LocalSearchSolvers._add!(c, 3)
    @test 3 ∈ c
    LocalSearchSolvers._delete!(c, 3)
    @test 3 ∉ c
    @test LocalSearchSolvers._length(c) == 2
    c.f(values...)
end

## test objective
o1 = objective(sum, "Objective 1: sum")
o2 = objective(prod, "Objective 2: product")
objs = Dictionary(1:2, [o1, o2])

for o in objs
    @test o.f(values) == 6
end

## test Problem
# TODO: update tests
# p = Problem(variables=vars, objectives=objs, constraints=cons)
m = Model()
@test_logs describe(m)

x1 = variable([4,3,2,1], "x1")
x2 = variable(d2, "x2")
vars = Dictionary{Int, Variable}(1:2, [x1, x2])
for x in vars
    add!(m, x)
end
variable!(m, d1)

values = [1, 2, 3]
inds = [1, 2]
c1 = constraint(err, inds, values)
c2 = constraint(err, inds, vars)
cons = Dictionary{Int, Constraint}(1:2, [c1, c2])
for c in cons
    add!(m, c)
end
constraint!(m, err, [1,2])

o1 = objective(sum, "Objective 1: sum")
o2 = objective(prod, "Objective 2: product")
objs = Dictionary(1:2, [o1, o2])
for o in objs
    add!(m, o)
end

# TODO: make related test to coverage below
objective!(m, max)
length_var(m, 1)
length_cons(m, 1)
constriction(m, 1)
draw(m, 1)
get_objective(m, 1)
delete_value!(m, 1, 1)
add_value!(m, 1, 1)
delete_var_from_cons!(m, 1, 1)
add_var_to_cons!(m, 1, 1)
@test_logs describe(m)

## Test Solver
s1 = Solver()
