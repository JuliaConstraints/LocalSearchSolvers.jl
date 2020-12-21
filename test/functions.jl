v = [1,2,3,4]

@test o_dist_extrema(v...) == 3.0
@test c_dist_different(v...) == 1.0
@test c_all_equal(v...) == 3.0
