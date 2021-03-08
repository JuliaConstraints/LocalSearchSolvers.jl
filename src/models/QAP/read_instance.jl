using DelimitedFiles

function ReadInstance(file::String)
    @info "reading instance.."
    println(file)
    println()
    instance = readdlm(file);
    n = instance[1,1];
    W = instance[2:n+1,1:n];
    D = instance[n+2:2n+1,1:n];
    W = convert(Array{Int64,2}, W);
    D = convert(Array{Int64,2}, D);
    return (n, W, D);
end