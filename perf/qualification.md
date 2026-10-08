# Owned initialization and reset qualification — 8 October 2026

Baseline: LocalSearchSolvers `57c5aaff0c2714e42e3c2a4335617354d08120ef`,
CBLS `3687ece072aa2dc17f4eee87eadd706d97ab6752`,
MetaStrategist `3c6ad5b057af4910bed99412ba24f7bc8d329587`.

Initialization uses one owned maximum-arity input vector and the established
ephemeral read-only evaluator protocol. Public `Configuration` construction
remains available. Type-union construction folds over types without splatting
an arity-dependent argument list. Preparation receipts display each distinct
evaluator type once in a local dictionary, preserving the ordered tuple of
descriptions. There is no persistent metadata cache.

`owned_scenarios.jl` supplies original ring-sum and objective oracles. The reset
case prepares a typed unit, runs 64 steps, and restores its private baseline.
The episode case runs two private units for exactly 256 steps each. The
candidate case performs 1,024 rejected block candidates, 1,024 accepted block
commits and 1,024 restoration commits. Unlimited wall time does not change the
work counts. No learned truth or constraint semantics were substituted.

Julia 1.13.1; affinity 0,2 (two physical cores); Julia threads 2, GC threads 1,
BLAS/OpenMP threads 1, precompile tasks 1. Tools were added offline in a
temporary diagnostic environment. Before/after solver dependencies match;
diagnostic resolution selected Parsers 2.8.8. Frozen source and parent benchmark
checkouts were read-only. Shared-machine times are operational observations,
not controlled scaling evidence.

| Warm fixed work | Before bytes / objects | After bytes / objects | Before seconds (3 samples) | After seconds (3 samples) |
|---|---:|---:|---|---|
| initialize 128 variables, including seed reset | 139,096 / 2,003 | 122,072 / 1,614 | .000143833, .000142273, .000142281 | .000128817, .000128176, .000126823 |
| restore typed 32-variable unit | 2,780,400 / 7,978 | 249,872 / 2,535 | .005885859, .005767354, .005834063 | .000582327, .000677934, .000573486 |
| two workers, 256 steps each | 613,904 / 13,769 | 613,904 / 13,769 | .000797776, .000774134, .000867215 | .000809973, .000778119, .000798342 |
| 1,024 candidate/commit cycles | 32,816 / 2,050 | 32,816 / 2,050 | .000844642, .000846357, .003840870 | .000840899, .000849145, .000850205 |

The reset improvement combines this package with MetaStrategist's streaming
canonical encoder; it is not attributed to initialization alone. Object counts
are `@timed.gcstats.poolalloc + bigalloc`. These warm samples had zero measured
compilation, collection time and lock conflicts. Episode and candidate work
did not demonstrate an allocation improvement in this increment.

Independent raw state initialization, excluding seed reset, changed from
36,120 bytes / 549 objects to 32,024 / 450 for 32 variables, and from 138,696 /
1,995 to 121,672 / 1,606 for 128 variables. On an identical CBLS receipt model,
32 repeated evaluator type descriptions changed from 2,538,576 / 3,811 to
80,352 / 126; 128 changed from 10,154,144 / 15,235 to 81,968 / 126. The original
and new ordered strings were asserted equal.

Cold first-operation observations excluding fixture construction: state128
was .597 s / 77.5 MB before and .583 s / 75.5 MB after; reset32 was .232 s /
10.8 MB before and .226 s / 8.2 MB after. Compilation dominated. PerfChecker's
separate full-lifecycle observations were source/first/warm 1.019/8.894/.00845 s
for episodes and 1.025/9.722/.00399 s for reset. Instrumentation and scopes
differ, so these are not cold-start speed claims.

Validation: all 11,860 LocalSearchSolvers checks passed, including independent
initialization oracles, union reduction, private input/invariant/neighborhood
ownership and two-worker exact seeded reset/replay. MetaStrategist's 201 checks
also passed. Aqua's full package checks passed after adding missing test-extra
compatibility bounds. MetaStrategist is an explicit test extra so extension
ownership regressions run in the package test environment.

PerfChecker 1.0.0 benchmark, Chairmarks, CPU profile and full allocation profile
collectors all executed both episodes and reset with passing oracles. Benchmark
and Chairmarks confirmed the episode allocation totals above and approximately
249,872 bytes / 2,549 objects for reset; a few receipt/measurement objects vary
with process labels and instrumentation.

JET 0.12.3 reported 245 full-episode and 72 full-reset findings, including cold
ownership WeakKeyDict/Any dispatch, graph restoration and runtime orchestration.
The concrete incremental `_candidate_cost(context, move)` and
`_commit!(context, move)` each had zero JET findings and zero measured allocated
bytes. The full lifecycle is not inference-clean. SnoopCompile 3.2.9 measured
46.348 s inclusive episode inference and 20.796 s reset inference under its
instrumentation. GC and lock analyzers completed; three warm samples had no
collection or lock conflict. Reachable episode state increased by about 1,200
bytes after incumbent storage; reset state by about 5,946 bytes after a receipt
history append (the builder bounds history to 64 entries). These observations
are not leak findings.

Remaining candidate-cycle allocation stacks identify 16-byte boxing in the
solver wrapper for `_compute_committed_costs!`, rather than candidate or commit
evaluation. Restore still copies the owned baseline graph and builds immutable
receipt metadata. Raw profiles and bulk analyzer reports are not committed.

## Concrete cost-finalization barrier

A subsequent increment combines cost updates and finalization behind one
function barrier receiving the actual model and state. It preserves the public
full and committed compute methods and their Boolean satisfaction result. The
discarded Float64 cost result no longer crosses an abstract solver-field boundary.

Against the preceding owned-input increment, the identical 1,024 candidate case
changed from 32,848 bytes / 2,051 objects to 80 bytes / 3 objects. Three warm
before times were .000818237/.000844200/.000828420 s; after
.000763471/.000781376/.000755201 s. No compile or collection time was recorded.
The small timing difference is operational; the eliminated per-commit boxing
is the measured result. Full-operation JET findings changed from 99 to 98;
ownership, pool and solver-shell dispatch remain, so this is not an
inference-clean full lifecycle.

All 11,878 LocalSearchSolvers checks passed after this increment. Eighteen added
checks cover full and incremental cost paths, infeasible-to-feasible transitions,
objective values, exact assignments and bounded allocation over 128 pairs of
commits through a concrete search context. The prepared typed iteration already
used concrete model/state cost updates; no typed-episode speedup is claimed.

Scoped AllocCheck subsequently executed the same concrete candidate and commit
signatures. It reported 11 and 3 possible allocations respectively: cold vector
growth, generation-array resizing and full-evaluation fallback branches. Warm
zero-allocation observations and zero JET findings do not prove static allocation
freedom for all reachable cold or dynamic-model paths.

## Integer tabu maintenance fast paths

Private integer tabu tables now return immediately when empty and skip the
structural filter/rehash when no duration equals one. Decay still subtracts one
from every surviving entry. Empty clearing returns the same table without
filtering it again. Nonempty clearing and generic external table protocols keep
their previous paths. No tenure or accepted/proposal clock policy changed.

A bounded 256-step owned-unit trace contained 60 steps with an expiring entry,
103 with a nonempty nonexpiring table and 93 with an empty table. Thus the
structural fast paths applied on 77% of this trace. Allocation profiling found
one boxed filter-local value per structural call; no dependency source was edited.

`tabu_scenarios.jl` supplies 1,024 decay calls on sixteen nonexpiring entries,
and 1,024 empty decay/clear pairs. For a same-process comparison, exact before
source from `35671c8daba2a293dd431dfe80f59da73bc7596d` was loaded into an
in-memory module. Both versions used the same dictionary dependency, warmed
operations, sample-order seed 91 and the two-core limits above. Collection was
outside timing; all samples had zero measured compilation and collection.

| Matched component work | Before bytes / objects | After bytes / objects | Before seconds (3 samples) | After seconds (3 samples) |
|---|---:|---:|---|---|
| 1,024 nonexpiring decays | 16,848–18,576 / 1,033–1,070 | 464 / 9 | .000074950, .000069362, .000072191 | .000025437, .000024956, .000025225 |
| 1,024 empty decay/clear pairs | 33,232 / 2,057 | 464 / 9 | .000102115, .000094840, .000091440 | .000006731, .000006692, .000005359 |

The in-memory comparison harness contributes constant overhead. All four
PerfChecker collectors passed both real component factories and measured zero
warm operation bytes/objects. Three GC and lock samples also measured zero
allocation, collection, compilation and conflicts. Reachable fixture state
stayed 1,560 bytes for decay and 544 bytes for empty maintenance; including the
existing table result added 16 bytes in each case.

Two typed units also executed 256 steps each per observation. Both workers'
exact assignments and independent ring-sum errors agreed before/after in all
three observations. Allocation changed from 468,400 / 12,119 to 462,448 / 11,747,
70,224 / 1,930 to 67,824 / 1,780, and 489,008 / 12,639 to 482,784 / 12,250.
Continuing units carry their state between observations, so these observations
are paired separately. Wall times varied substantially on the shared machine;
no overall episode speedup or scaling gain is claimed.

All 14,746 LocalSearchSolvers package checks passed, including full Aqua and
2,868 new order/tombstone/nonpositive-duration, event-clock and allocation
checks. JET reported 4/6 findings for decay/empty operation specializations;
AllocCheck reported 8/12 possible allocations on reachable structural filtering
paths. Zero warm allocation applies to these specified states, rather than all
tabu states. Raw reports and the comparison module were not saved.

## Owned pool snapshots for bit-valued assignments

For bit-valued assignments, pool construction copies the configuration's scalar
fields directly and uses the dictionary's existing deep-copy operation. This
avoids traversing the outer configuration while retaining private indices and
assignment storage. Other assignment types retain whole-configuration copying,
including mutable values that refer back to the configuration. Published pools
remain independent snapshots. Multi-solution history copying is unchanged.

`pool_scenarios.jl` measures 128 new snapshots and 128 admitted publications,
with independent storage, assignment and score checks. The baseline is
LocalSearchSolvers `d26a070f8d87176a8f8bc9c172c59c683b3c2bd5`; CBLS
`2c453ddee7f3af7433573969916caec1918fe8d4`, MetaStrategist
`f64bfa4d68f3f80b08eee473a3bfc90f56e0fb5d` and resolved dependencies are unchanged.
The two-core limits above apply. Collection is outside the timed operations;
all listed samples have zero measured compilation and collection time.

| Warm matched work | Before bytes / objects | After bytes / objects | Before seconds (3 samples) | After seconds (3 samples) |
|---|---:|---:|---|---|
| 128 snapshots, 32 values | 376,832 / 3,456 | 366,592 / 3,072 | .000092786, .000086679, .000089554 | .000074356, .000067374, .000069694 |
| 128 snapshots, 128 values | 1,086,464 / 3,584 | 1,076,224 / 3,200 | .000191976, .000173846, .000162958 | .000144801, .000198854, .000152885 |
| 128 publications, 32 values | 376,832 / 3,456 | 366,592 / 3,072 | .000102561, .000102870, .000094848 | .000073571, .000133590, .000077920 |
| 128 publications, 128 values | 1,086,464 / 3,584 | 1,076,224 / 3,200 | .000169269, .000166231, .000169857 | .000148833, .000148345, .000171521 |

All 14,977 package checks pass, including full Aqua and 231 new checks for
ordered assignments with dictionary holes, private storage, exact floating-point
score bits, dictionary copy semantics, shared mutable values and root cycles.
These new checks and concurrent publication checks also pass with the original
pool method loaded directly from the baseline commit in memory.

All four PerfChecker collectors pass both 32-value cases, agreeing on
366,592 bytes / 3,072 objects. Snapshot JET has zero findings; publication JET
has 98 findings through its broader dynamic solver paths. AllocCheck reports
52/223 possible allocations respectively. Snapshotting intentionally allocates
private storage. Three GC and lock samples show no compilation, collection or
conflicts. Reachable snapshot fixture state stays 1,504 bytes, or 3,104 bytes
including its independently owned result. Publication fixture size changes
from 5,795 to 7,379 bytes when its initially empty pool acquires one snapshot;
with its scalar result it is 7,387 bytes, consistent across samples.

A same-process comparison loaded each original/final pool method directly from
its source, warmed two episodes, then ran two private typed units for exactly
256 steps each per observation. Both assignments and errors match in all three
observations. Bytes / objects are 463,520 / 11,770 versus 463,024 / 11,759;
67,824 / 1,780 versus 68,736 / 1,796; and 482,784 / 12,250 versus the same values.
Continuing units carry their state; task scheduling adds small allocation
variation. No overall episode allocation reduction, throughput or scaling gain
is claimed. Raw reports and comparison definitions are not saved.

## Public block commit boundary

The solver-level commit wrapper passes a block move's already-owned fields
through the runtime model/state boundary, then reconstructs the same immutable
move inside the concrete operation. Variable order, replacements, provenance
and extension dispatch are retained. Concrete search contexts keep their
existing path. The wrapper avoids boxing the whole 48-byte move; this specified
one-symbol metadata tuple still requires a 16-byte box per public commit.

`public_commit_scenarios.jl` performs exactly 2,048 commits per operation,
alternating all-one/all-zero eight-variable blocks in a 32-variable model. Full
and incremental cost policies have independent final truth, objective and
untouched-variable checks. The baseline is LocalSearchSolvers
`dca296e339cbdf617e2645f1871983a134920d80`, with unchanged CBLS
`2c453ddee7f3af7433573969916caec1918fe8d4`, MetaStrategist
`0b761608726025d2fec402ad18b6e1773045fa2b` and resolved dependencies. Two-core
limits apply. Collection is requested outside timed operations.

| Warm reused fixture, 2,048 commits | Before bytes / objects | After bytes / objects | Before seconds (3 samples) | After seconds (3 samples) |
|---|---:|---:|---|---|
| full-cost | 98,368 / 2,050 | 32,832 / 2,050 | .000261261, .000257887, .000277554 | .000250550, .000248867, .000249055 |
| incremental | 98,368 / 2,050 | 32,832 / 2,050 | .000422237, .000330133, .000336291 | .000392586, .000384827, .000390847 |

A same-process comparison loads the original/final wrapper from source in
memory, randomizes their order (seed 91), warms twice after each method change
and takes six paired observations. Allocation is consistently 98,432 versus
32,896 bytes, with 2,050 objects on both sides; its invocation wrapper adds
constant bytes relative to the table. Full-cost times span .000245–.000280 s
before and .000247–.000280 s after; incremental times span .000328–.000366 s
before and .000342–.000387 s after. These shared-machine timings do not establish
a throughput improvement. All samples have zero compilation and collection.

All 16,725 package checks and full Aqua pass, including 1,740 new tests of atomic
scores, borrowed affected-constraint storage and external move dispatch with
mutable identity-bearing provenance. They cover integer/float assignments,
static full/incremental policies and dynamic full-cost models. Eight allocation
checks cover the specified integer metadata case. The existing concrete typed
The 1,740 score/dispatch checks also pass with the original wrapper loaded from
the baseline source in memory.
candidate/commit case remains 80 bytes / three constant measurement objects
across 1,024 accepted/rejected cycles.

All four PerfChecker collectors pass both policies and agree on 35,632 bytes /
2,072 objects for their fresh-fixture operation. This scope includes first use
of a newly prepared state and differs from the reused-fixture table. JET reports
113 findings through broader solver fields for each policy; AllocCheck reports
six possible allocations. Three GC and lock samples show zero collection,
compilation or conflicts. Reachable state stays 34,321 bytes (full) or 34,985
bytes (incremental), unchanged with the `nothing` result. Raw reports and
temporary comparison definitions are not saved.
