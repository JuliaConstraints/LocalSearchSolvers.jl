v = [1,2,3,4]

@test dist_extrema(v...) == 3.0
@test dist_different(v...) == 1.0