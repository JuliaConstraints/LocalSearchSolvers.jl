mutable struct TimeStamps # seconds
    ts0::Float64 # model construction start
    ts1::Float64 # ts1 ≤ _init!
    ts2::Float64 # _init! ≤ ts2 ≤ @threads
    ts3::Float64 # @threads ≤ ts3 ≤ remote_start
    ts4::Float64 # remote_start ≤ ts4 ≤ main_run
    ts5::Float64 # main_run ≤ ts5 ≤ remote_stop
    ts6::Float64 # remote_stop ≤ ts6
end

function TimeStamps(ts::Float64 = zero(Float64))
    t = zero(Float64)
    return TimeStamps(ts, t, t, t, t, t, t)
end
TimeStamps(model::_Model) = TimeStamps(get_time_stamp(model))

add_time!(stamps, ts, ::Val{1}) = stamps.ts1 = ts
add_time!(stamps, ts, ::Val{2}) = stamps.ts2 = ts
add_time!(stamps, ts, ::Val{3}) = stamps.ts3 = ts
add_time!(stamps, ts, ::Val{4}) = stamps.ts4 = ts
add_time!(stamps, ts, ::Val{5}) = stamps.ts5 = ts
add_time!(stamps, ts, ::Val{6}) = stamps.ts6 = ts

add_time!(stamps, i) = add_time!(stamps, time(), Val(i))

get_time(stamps, ::Val{1}) = stamps.ts1
get_time(stamps, ::Val{2}) = stamps.ts2
get_time(stamps, ::Val{3}) = stamps.ts3
get_time(stamps, ::Val{4}) = stamps.ts4
get_time(stamps, ::Val{5}) = stamps.ts5
get_time(stamps, ::Val{6}) = stamps.ts6

get_time(stamps, i) = get_time(stamps, Val(i))


function time_info(stamps)
    info = Dict([
        :model => stamps.ts1 - stamps.ts0,
        :init => stamps.ts2 - stamps.ts1,
        :threads_start => stamps.ts3 - stamps.ts2,
        :remote_start => stamps.ts4 - stamps.ts3,
        :local_run => stamps.ts5 - stamps.ts4,
        :remote_stop => stamps.ts6 - stamps.ts5,
        :total_run => stamps.ts6 - stamps.ts1,
        :model_and_run => stamps.ts6 - stamps.ts0,
    ])
    return info
end
