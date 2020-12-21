"""
    ordered(x::Int...)
Global constraint ensuring that all the values of `x` are ordered.
"""
c_ordered(x::Int...) = issorted(x) ? 0.0 : 1.0
