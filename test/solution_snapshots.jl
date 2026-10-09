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

@testset "Compact snapshots preserve deleted keys and later independent mutations" begin
    for T in (Int,UInt128,Bool,Float16,Float32,Float64),count in (0,1,8,32),deleted in (:none,:one,:sparse,:all)
        ids=collect(1:count)
        values=T===Bool ? isodd.(ids) : T.(mod.(ids,8))
        dictionary=Dictionary(ids,values)
        remove=deleted===:none ? Int[] : deleted===:one ? (count==0 ? Int[] : [1]) :
            deleted===:sparse ? collect(2:3:count) : ids
        foreach(id->delete!(dictionary,id),remove)
        config=LS.Configuration(false,-0.0,dictionary)
        reference=deepcopy(config)
        saved=LS.best_config(LS.pool(config))
        expected=collect(pairs(reference.values))
        @test isequal(collect(pairs(saved.values)),expected)
        @test keys(saved.values)!==keys(dictionary)
        @test saved.values.values!==dictionary.values
        @test reinterpret(UInt64,saved.value)==reinterpret(UInt64,reference.value)
        @test all(id->bitstring(saved.values[id])==bitstring(reference.values[id]),keys(saved.values))
        set!(dictionary,count+101,T===Bool ? true : T(3))
        @test isequal(collect(pairs(saved.values)),expected)
        set!(saved.values,count+103,T===Bool ? false : T(5))
        @test !haskey(dictionary,count+103)
        @test !haskey(saved.values,count+101)
    end
end

struct SnapshotBitValue
    value::Int
end
const snapshot_dictionary_copy_calls=Ref(0)
const snapshot_copy_callback_owner=Ref{Any}(nothing)
function Base.deepcopy_internal(dictionary::Dictionary{Int,SnapshotBitValue},seen::IdDict)
    snapshot_dictionary_copy_calls[]+=1
    if snapshot_copy_callback_owner[]!==nothing
        snapshot_copy_callback_owner[].solution=true
        snapshot_copy_callback_owner[].value=99.0
    end
    invoke(Base.deepcopy_internal,Tuple{Dictionary,IdDict},dictionary,seen)
end

@testset "Custom bit-value dictionaries retain their deep-copy extension" begin
    for count in (0,1,8),score in (0.0,-0.0,NaN,Inf)
        dictionary=Dictionary(collect(1:count),SnapshotBitValue.(1:count))
        config=LS.Configuration(false,score,dictionary)
        snapshot_dictionary_copy_calls[]=0
        saved=LS.best_config(LS.pool(config))
        @test snapshot_dictionary_copy_calls[]==1
        @test collect(pairs(saved.values))==collect(pairs(dictionary))
        @test keys(saved.values)!==keys(dictionary) && saved.values.values!==dictionary.values
        @test bitstring(saved.value)==bitstring(score)
    end
end

@testset "Snapshot metadata is read before a custom copy callback" begin
    config=LS.Configuration(false,-0.0,Dictionary([1],[SnapshotBitValue(7)]))
    snapshot_dictionary_copy_calls[]=0
    snapshot_copy_callback_owner[]=config
    try
        saved=LS.best_config(LS.pool(config))
        @test snapshot_dictionary_copy_calls[]==1
        @test !saved.solution && bitstring(saved.value)==bitstring(-0.0)
        @test config.solution && config.value==99.0
    finally
        snapshot_copy_callback_owner[]=nothing
    end
end

end
