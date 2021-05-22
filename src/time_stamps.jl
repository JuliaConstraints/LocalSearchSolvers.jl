mutable struct TimeStamps # seconds
    ts1::Float64 # ts1 ≤ solve!
    ts2::Float64 # solve! ≤ ts2 ≤ _init!
    ts3::Float64 # _init! ≤ ts3 ≤ @threads
    ts4::Float64 # @threads ≤ ts4 ≤ remote_start
    ts5::Float64 # remote_start ≤ ts5 ≤ main_run
    ts6::Float64 # main_run ≤ ts6 ≤ remote_stop
    ts7::Float64 # remote_stop ≤ ts7
end

TimeStamps(ts::Float64 = zero(Float64)) = TimeStamps(-ts, -ts, -ts, -ts, -ts, -ts, -ts)
TimeStamps(model::_Model) = TimeStamps(get_time_stamp(model))
