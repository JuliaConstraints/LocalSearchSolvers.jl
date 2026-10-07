module CBLSFixFixture
using Distributed, Random
import LocalSearchSolvers as LS
const MAIN_CALLS=Ref(0)
function error_function(x;X)
    abs(sum(x)-2.0)
end
function remote_failure(x;X)
    myid()==1 || error("intentional remote failure")
    1.0
end
function main_failure(x;X)
    if myid()==1
        MAIN_CALLS[]+=1
        MAIN_CALLS[]>20 && error("intentional main failure")
    end
    1.0
end
function build(map;kind=:optimization,budget=16,solutions=1,seconds=30.0)
    m=LS.model();foreach(_->LS.variable!(m,LS.domain(0:2)),1:2)
    penalty=kind==:remote_error ? remote_failure : kind==:main_error ? main_failure :
        kind==:unsatisfiable ? ((x;X)->1.0) : kind==:many ? ((x;X)->0.0) : error_function
    LS.constraint!(m,penalty,1:2)
    kind in (:optimization,:max) && LS.objective!(m,x->10.0+x[1]+2x[2])
    kind==:max && LS.sense!(m,Val(:max))
    options=LS.Options(iteration=(false,budget),time_limit=(false,seconds),solutions=solutions,
        process_threads_map=map,print_level=:silent,log_mode=:silent,log_to_file=false,
        progress_mode=:none,use_progress_meter=false)
    LS.solver(m;options)
end
function truth(s)
    pool=LS._pool_snapshot(s);values=collect(LS.best_values(pool))
    error=LS.compute_costs(s.model,LS.best_values(pool),copy(s.state.icn_computations))
    objective=LS.is_sat(s) ? error : LS.sense(s)*LS.compute_objective(s.model,values)
    (values=values,error=error,score=LS.best_value(pool),objective=objective,
        feasible=LS.has_solution(pool),iterations=LS.iterations(s),subs=LS.iterations.(s.subs))
end
end
