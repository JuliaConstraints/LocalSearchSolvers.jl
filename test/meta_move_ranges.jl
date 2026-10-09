module MetaMoveRangeTests
using Test, LocalSearchSolvers
const LS = LocalSearchSolvers

function outcome(f)
    try
        value = f()
        value isa LS.MetaVariable ? (;kind=:variable,id=value.id,
            variables=copy(value.variables),provenance=value.provenance) :
            (;kind=:move,id=value.meta_variable,variables=copy(value.variables),
                replacements=copy(value.replacements),provenance=value.provenance)
    catch error
        (typeof(error),sprint(showerror,error))
    end
end

@testset "Built-in integer range requests retain public constructor semantics" begin
    group = LS.MetaVariable(:block,1:12)
    ranges = Any[a:b for a in -4:12 for b in -4:12]
    append!(ranges,[a:step:b for a in -4:12 for step in (-4,-3,-2,-1,1,2,3,4) for b in -4:12])
    for range in ranges
        ids = [id for id in range]
        replacements = [100+id for id in ids]
        provenance = (;source=:range_oracle)
        @test outcome(() -> LS.MetaVariable(:range,range;provenance)) ==
            outcome(() -> LS.MetaVariable(:range,ids;provenance))
        @test outcome(() -> LS.MetaMove(group,range,replacements;provenance)) ==
            outcome(() -> LS.MetaMove(group,ids,replacements;provenance))
    end
end

struct RangeScope{R} <: LS.AbstractMetaVariable
    ids::R
    calls::Base.RefValue{Int}
end
LS.meta_variable_id(::RangeScope) = :range
function LS.scope(group::RangeScope)
    group.calls[] += 1
    group.ids
end

@testset "Range scopes and retained moves own separate integer vectors" begin
    for ids in (1:8,1:2:15,8:-1:1,15:-2:1,1:128,1:2:255,128:-1:1)
        first_scope = LS.MetaVariable(:first,ids)
        second_scope = LS.MetaVariable(:second,ids)
        expected = sort!([id for id in ids])
        @test first_scope.variables == second_scope.variables == expected
        @test first_scope.variables !== second_scope.variables
        first_scope.variables[1] = -1
        @test second_scope.variables == expected
        values = [100+id for id in ids]
        scope = RangeScope(ids,Ref(0))
        move = LS.MetaMove(scope,values)
        @test scope.calls[] == 1
        @test move.variables == [id for id in ids] && move.replacements == values
        @test move.replacements !== values
        values[1] = -1
        @test move.replacements[1] == 100+first(ids)
        other = LS.MetaMove(scope,[100+id for id in ids])
        @test other.variables !== move.variables && other.replacements !== move.replacements
        move.variables[1] = -2
        @test other.variables == [id for id in ids]
    end
end

@testset "Other range element types retain conversion behavior" begin
    for ids in (Int32(1):Int32(8),Int32(8):Int32(-1):Int32(1),
            UInt(1):UInt(8),1.0:1.0:8.0,1.0:0.5:3.0,Float32(1):Float32(1):Float32(8))
        @test outcome(() -> LS.MetaVariable(:range,ids)) ==
            outcome(() -> LS.MetaVariable(:range,[id for id in ids]))
    end
end
end
