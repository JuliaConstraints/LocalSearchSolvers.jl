module MetaMoveConstructorTests
using Test, LocalSearchSolvers
const LS = LocalSearchSolvers

@testset "Partial meta-moves preserve membership and validation" begin
    provenance = (;source=:constructor_test)
    for count in 0:6, mask in 0:((1 << count)-1)
        available = [id for id in 1:count if isodd(mask >> (id-1))]
        for layout in (available, reverse(available), vcat(available,available),
                vcat([-1,0],available))
            # Exercise edited/public scope storage as well as the usual sorted scope.
            group = LS.MetaVariable(:group, copy(layout), provenance)
            for ids in (Int[], [-1], [0], [1], [count], [count+1], [1,1],
                    collect(1:count), available, reverse(available))
                replacements = collect(101:(100+length(ids)))
                valid = !isempty(ids) && allunique(ids) && all(id -> id in layout, ids)
                result = try
                    LS.MetaMove(group, ids, replacements; provenance)
                catch error
                    error
                end
                if valid
                    @test result isa LS.MetaMove
                    @test result.variables == sort(ids)
                    @test result.replacements ==
                        [replacements[findfirst(==(id),ids)] for id in sort(ids)]
                    @test result.variables !== ids && result.variables !== group.variables
                    @test result.replacements !== replacements
                    @test result.provenance === provenance
                else
                    @test result isa ArgumentError
                    message = isempty(ids) ? "a meta-move cannot be empty" :
                        !allunique(ids) ? "a meta-move cannot change a variable twice" :
                        "a meta-move must stay inside its meta-variable scope"
                    @test sprint(showerror,result) == "ArgumentError: $message"
                end
            end
        end
    end
end

@testset "Meta-variable and move inputs remain independently owned" begin
    for ids in ([3,1,2], Int32[3,1,2], [3.0,1.0,2.0], (3,1,2), 1:3,
            Set([3,1,2]), (id for id in (3,1,2)), view([3,1,2],1:3))
        group = LS.MetaVariable(:group, ids)
        @test group.variables == [1,2,3]
        @test group.variables isa Vector{Int}
        @test group.variables !== ids
    end
    for invalid in (Int[], [0,1], [-1,1], [1,1])
        @test_throws ArgumentError LS.MetaVariable(:group, invalid)
    end
    @test_throws InexactError LS.MetaVariable(:group, [1.5,2.0])

    ids = [3,1,2]
    group = LS.MetaVariable(:group, ids)
    ids[1] = 9
    @test group.variables == [1,2,3]
    replacements = [7,8,9]
    first_move = LS.MetaMove(group, replacements)
    second_move = LS.MetaMove(group, replacements)
    @test first_move.variables == group.variables
    @test first_move.variables !== group.variables &&
        first_move.variables !== second_move.variables
    @test first_move.replacements == replacements
    @test first_move.replacements !== replacements &&
        first_move.replacements !== second_move.replacements
    replacements[1] = 10
    group.variables[1] = 4
    @test first_move.variables == [1,2,3] && first_move.replacements == [7,8,9]
    first_move.variables[1] = 5
    first_move.replacements[1] = 11
    @test second_move.variables == [1,2,3] && second_move.replacements == [7,8,9]
    @test_throws DimensionMismatch LS.MetaMove(group, [1,2])
    @test_throws DimensionMismatch LS.MetaMove(group, [1,2], [3])

    # Full-scope moves retain even an edited scope's order; the partial constructor sorts.
    group.variables .= [3,1,2]
    @test LS.MetaMove(group, [7,8,9]).variables == [3,1,2]
    @test LS.MetaMove(group, [3,1], [7,8]).variables == [1,3]
    @test LS.MetaMove(group, [3,1], [7,8]).replacements == [8,7]
    empty_group = LS.MetaVariable(:empty, Int[], (;source=:edited))
    @test isempty(LS.MetaMove(empty_group, Int[]).variables)
end

struct CountedScope{T} <: LS.AbstractMetaVariable
    id::Symbol
    variables::T
    calls::Base.RefValue{Int}
end
LS.meta_variable_id(group::CountedScope) = group.id
function LS.scope(group::CountedScope)
    group.calls[] += 1
    group.variables
end
@testset "Custom scope implementations retain their original call behavior" begin
    for variables in ([1,2,3], Int32[1,2,3], (1,2,3), 1:3)
        group = CountedScope(:custom, variables, Ref(0))
        partial = LS.MetaMove(group, [3,1], [7,9])
        @test group.calls[] == 2
        @test partial.variables == [1,3] && partial.replacements == [9,7]
        group.calls[] = 0
        @test_throws ArgumentError LS.MetaMove(group, [1,4,7], [1,2,3])
        @test group.calls[] == 2
        group.calls[] = 0
        full = LS.MetaMove(group, [7,8,9])
        @test group.calls[] == 1
        @test full.variables == [1,2,3] && full.variables !== variables
    end
end
end
