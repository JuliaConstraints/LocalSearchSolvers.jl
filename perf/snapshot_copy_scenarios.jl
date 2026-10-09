module SnapshotCopyScenarios
using LocalSearchSolvers,Dictionaries
const LS=LocalSearchSolvers

mutable struct SnapshotNode
    owner::Any
    payload::Vector{Int}
end

function configuration(count,precision,deleted,mutable_values)
    ids=collect(1:count)
    if mutable_values
        node=SnapshotNode(nothing,[1,2,3])
        values=fill(node,count)
    else
        T=precision=="Int" ? Int : precision=="Float32" ? Float32 :
            precision=="Float64" ? Float64 : throw(ArgumentError("snapshot precision"))
        values=T.(mod.(ids,8))
        if T<:AbstractFloat && count>=8
            values[1:8]=T[-0.0,0.0,Inf,-Inf,NaN,floatmin(T),floatmax(T),1.5]
        end
    end
    dictionary=Dictionary(ids,values)
    deleted && foreach(id->delete!(dictionary,id),2:3:count)
    config=LS.Configuration(false,-0.0,dictionary)
    mutable_values && count>0 && (node.owner=config)
    config
end

function snapshot_case(parameters)
    count=get(parameters,"variables",128)
    precision=get(parameters,"precision","Int")
    deleted=get(parameters,"deleted",false)
    mutable_values=get(parameters,"mutable_values",false)
    repetitions=get(parameters,"repetitions",128)
    prepare=()->configuration(count,precision,deleted,mutable_values)
    operation=config->begin
        result=Vector{LS._Pool{eltype(config.values)}}(undef,repetitions)
        for i in eachindex(result)
            result[i]=LS.pool(config)
        end
        result
    end
    verify=(config,result)->length(result)==repetitions &&
        all(pool->keys(LS.best_config(pool).values)!==keys(LS.best_config(first(result)).values) &&
            LS.best_config(pool).values.values!==LS.best_config(first(result)).values.values,
            Iterators.drop(result,1)) && all(result) do pool
        saved=LS.best_config(pool)
        keys(saved.values)!==keys(config.values) && saved.values.values!==config.values.values &&
            saved.solution===config.solution && bitstring(saved.value)==bitstring(config.value) &&
            collect(keys(saved.values))==collect(keys(config.values)) &&
            (!mutable_values || isempty(saved.values) ||
                all(value->value===first(saved.values),saved.values)) &&
            (mutable_values ? all(id->saved.values[id].owner===saved &&
                saved.values[id]!==config.values[id] &&
                saved.values[id].payload!==config.values[id].payload &&
                saved.values[id].payload==config.values[id].payload,keys(config.values)) :
                all(id->bitstring(saved.values[id])==bitstring(config.values[id]),keys(config.values)))
    end
    (;prepare,operation,verify)
end
end
snapshot_copy_case(parameters)=SnapshotCopyScenarios.snapshot_case(parameters)


module SnapshotExtensionScenarios
using LocalSearchSolvers,Dictionaries
const LS=LocalSearchSolvers
struct SnapshotBitValue
    value::Int
end
const dictionary_copy_calls=Ref(0)
const copy_callback_owner=Ref{Any}(nothing)
function Base.deepcopy_internal(dictionary::Dictionary{Int,SnapshotBitValue},seen::IdDict)
    dictionary_copy_calls[]+=1
    if copy_callback_owner[]!==nothing
        copy_callback_owner[].solution=true
        copy_callback_owner[].value=99.0
    end
    invoke(Base.deepcopy_internal,Tuple{Dictionary,IdDict},dictionary,seen)
end
function snapshot_case(parameters)
    count=get(parameters,"variables",32)
    repetitions=get(parameters,"repetitions",128)
    prepare=()->LS.Configuration(false,-0.0,
        Dictionary(collect(1:count),SnapshotBitValue.(1:count)))
    operation=config->begin
        before=dictionary_copy_calls[]
        pools=Vector{LS._Pool{SnapshotBitValue}}(undef,repetitions)
        copy_callback_owner[]=config
        try
            for i in eachindex(pools)
                config.solution=false
                config.value=-0.0
                pools[i]=LS.pool(config)
            end
        finally
            copy_callback_owner[]=nothing
        end
        (;pools,copies=dictionary_copy_calls[]-before)
    end
    verify=(config,result)->result.copies==repetitions && length(result.pools)==repetitions &&
        all(pool->begin
            saved=LS.best_config(pool)
            collect(pairs(saved.values))==collect(pairs(config.values)) &&
                keys(saved.values)!==keys(config.values) &&
                saved.values.values!==config.values.values &&
                !saved.solution && bitstring(saved.value)==bitstring(-0.0) &&
                pool.value==99.0 && config.solution && config.value==99.0
        end,result.pools)
    (;prepare,operation,verify)
end
end
snapshot_extension_case(parameters)=SnapshotExtensionScenarios.snapshot_case(parameters)
