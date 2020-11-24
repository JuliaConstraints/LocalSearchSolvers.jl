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
variables = Dictionary(1:2, [x1, x2])

@test LocalSearchSolvers._get(x2, 2) == 3
for x in variables
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
values = [1,3]
inds = [1, 2]
c1 = constraint(all_different, inds, values)
c2 = constraint(all_different, inds, variables)
constraints = Dictionary(1:2, [c1, c2])

for c in constraints
    LocalSearchSolvers._add!(c, 3)
    @test 3 ∈ c
    LocalSearchSolvers._delete!(c, 3)
    @test 3 ∉ c
    @test LocalSearchSolvers._length(c) == 2
    c.f(values...)
end
