d1 = domain([4,3,2,1])
d2 = domain(1:4)
domains = Dictionary(1:2, [d1, d2])
@testset "Internals: Domains" begin
    for d in domains
        # constructors and ∈
        for x in [1,2,3,4]
            @test x ∈ d
        end
        # length
        @test length(d) == 4
        # draw and ∈
        @test rand(d) ∈ d
    end
    # add!
    ConstraintDomains.add!(d1, 5)
    @test 5 ∈ d1
    # delete!
    delete!(d1, 5)
    @test 5 ∉ d1
end

x1 = variable([4,3,2,1])
x2 = variable(d2)
x3 = variable() # TODO: tailored test for free variable
vars = Dictionary(1:2, [x1, x2])
@testset "Internals: variables" begin
    for x in vars
        # add and delete from constraint
        LS._add_to_constraint!(x, 1)
        LS._add_to_constraint!(x, 2)
        LS._delete_from_constraint!(x, 2)
        @test x ∈ 1
        @test x ∉ 2
        @test LS._constriction(x) == 1
        @test length(x) == 4
        for y in [1,2,3,4]
            @test y ∈ x
        end
        @test rand(x) ∈ x
    end
    add!(x1, 5)
    @test 5 ∈ x1
    delete!(x1, 5)
    @test 5 ∉ x1
end

values = [1, 2, 3]
inds = [1, 2]
err = error_f(usual_constraints[:all_different])
c1 = constraint(err, inds)
c2 = constraint(err, inds)
cons = Dictionary(1:2, [c1, c2])
@testset "Internals: constraints" begin
    for c in cons
        LS._add!(c, 3)
        @test 3 ∈ c
        LS._delete!(c, 3)
        @test 3 ∉ c
        @test LS._length(c) == 2
        c.f(values, Matrix{Float64}(undef, 3, CompositionalNetworks.max_icn_length()); dom_size=3)
    end
end

o1 = objective(sum, "Objective 1: sum")
o2 = objective(prod, "Objective 2: product")
objs = Dictionary(1:2, [o1, o2])
@testset "Internals: objectives" begin
    for o in objs
        @test o.f(values) == 6
    end
end


m = model()
# LocalSearchSolvers.describe(m)

x1 = variable([4,3,2,1])
x2 = variable(d2)
vars = Dictionary(1:2, [x1, x2])

values = [1, 2, 3]
inds = [1, 2]
c1 = constraint(err, inds)
c2 = constraint(err, inds)
cons = Dictionary(1:2, [c1, c2])

o1 = objective(sum, "Objective 1: sum")
o2 = objective(prod, "Objective 2: product")
objs = Dictionary(1:2, [o1, o2])

@testset "Internals: model" begin
    for x in vars
        add!(m, x)
    end
    variable!(m, d1)


    for c in cons
        add!(m, c)
    end
    constraint!(m, err, [1,2])


    for o in objs
        add!(m, o)
    end

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
    # describe(m)
end

## Test Solver
s1 = solver()

LS.get_error(LS.EmptyState())
