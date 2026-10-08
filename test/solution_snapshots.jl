module SolutionSnapshotTests
using Test, Dictionaries
import LocalSearchSolvers as LS

mutable struct SnapshotNode
    owner::Any
    payload::Vector{Int}
end

@testset "Pool snapshots retain private storage, order and floating-point bits" begin
    for values in (collect(1:12), [0.0, -0.0, Inf, -Inf, NaN, 1.5]),
            score in (0.0, -0.0, Inf, -Inf, NaN), solved in (false, true)
        dictionary = Dictionary(1:length(values), copy(values))
        delete!(dictionary, 2)
        set!(dictionary, 17, first(values))
        config = LS.Configuration(solved, score, dictionary)
        saved = LS.best_config(LS.pool(config))
        @test saved !== config
        @test saved.values !== dictionary
        @test keys(saved.values) !== keys(dictionary)
        @test saved.values.values !== dictionary.values
        @test isequal(collect(pairs(saved.values)), collect(pairs(dictionary)))
        @test saved.solution === solved
        @test reinterpret(UInt64, saved.value) == reinterpret(UInt64, score)
        expected = collect(pairs(saved.values))
        empty!(dictionary)
        set!(dictionary, 23, last(values))
        config.value = 77.0
        config.solution = !solved
        @test isequal(collect(pairs(saved.values)), expected)
        @test saved.solution === solved
        @test reinterpret(UInt64, saved.value) == reinterpret(UInt64, score)
        set!(saved.values, 29, first(values))
        @test !haskey(dictionary, 29)
    end
end

@testset "Snapshot copying retains the dictionary's existing deep-copy semantics" begin
    indices = Indices(1:8)
    dictionary = Dictionary{Int,Int}(indices, indices.values, nothing)
    config = LS.Configuration(false, 1.0, dictionary)
    reference = deepcopy(config)
    saved = LS.best_config(LS.pool(config))
    @test (saved.values.values === keys(saved.values).values) ==
        (reference.values.values === keys(reference.values).values)
    @test saved.values.values !== dictionary.values
    @test keys(saved.values).values !== indices.values
    @test collect(pairs(saved.values)) == collect(pairs(dictionary))
end

@testset "Mutable assignment values retain root cycles and shared payloads" begin
    node = SnapshotNode(nothing, [1,2,3])
    config = LS.Configuration(true, 2.0, Dictionary([1,2], [node,node]))
    node.owner = config
    saved = LS.best_config(LS.pool(config))
    @test saved !== config
    @test saved.values[1] === saved.values[2]
    @test saved.values[1] !== node
    @test saved.values[1].owner === saved
    @test saved.values[1].payload !== node.payload
    push!(node.payload, 4)
    @test saved.values[1].payload == [1,2,3]
    saved.values[1].owner.value = 9.0
    @test config.value == 2.0
end
end
