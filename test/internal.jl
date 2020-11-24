## test domains
d1 = domain([4,3,2,1])
d2 = domain([4,3,2,1]; domain = :indices)
domains = [d1, d2]

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
    @test !(5 ∈ d)
end
