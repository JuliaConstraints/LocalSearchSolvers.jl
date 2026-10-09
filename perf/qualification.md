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
checks cover the specified integer metadata case. The 1,740 score/dispatch
checks also pass with the original wrapper loaded from the baseline source in
memory. The existing concrete typed
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

## Meta-variable and move construction, 2026-10-09

Plain `Vector{Int}` variable ids now use an owned copy rather than argument
expansion. Other input iterables retain their original conversion path. Partial
moves validate sorted ids against a sorted `MetaVariable` scope in one forward
pass. Edited unsorted scopes keep ordinary membership checks, and custom scope
implementations keep their original public calls and short-circuit behavior.
Every move still owns fresh variable and replacement vectors.

The baseline is `bcc516b6fa1d3edc9732bebb38a009719491c8d1` in a temporary
source checkout. Dependency versions and source paths match except for
LocalSearchSolvers; CBLS evaluator source is `93e83b6` and MetaStrategist is
`8bcf8b2`. Julia 1.13.1 uses CPUs 0/2, two Julia threads and one GC thread.
Three complete warmups precede five observations of each exact operation.
Compilation, recompilation and GC totals are zero in all measured rows.

| 128 retained constructions | Before bytes / objects | After bytes / objects |
| --- | ---: | ---: |
| Full move, 8 ids | 41,032 / 643 | 36,936 / 515 |
| Full move, 128 ids | 294,984 / 643 | 290,888 / 515 |
| Full move, 2,048 ids | 9,482,312 / 197,763 | 4,216,904 / 771 |
| Partial move, 8 ids | 90,184 / 1,411 | 86,088 / 1,283 |
| Partial move, 128 ids | 725,064 / 1,411 | 720,968 / 1,283 |
| Partial move, 2,048 ids | 15,801,416 / 198,915 | 10,536,008 / 1,923 |
| Meta-variable, 8 ids | 23,624 / 387 | 19,528 / 259 |
| Meta-variable, 128 ids | 150,600 / 387 | 146,504 / 259 |
| Meta-variable, 2,048 ids | 7,374,920 / 197,379 | 2,109,512 / 387 |

The 2,048-id partial case takes .065358–.065829 s before and
.001616–.001697 s after. The 128-id full case takes .000239–.000262 s before
and .0000227–.0000347 s after. These are fixed construction workloads on a
shared machine. They do not establish application throughput or search quality.

Complete construct/public-commit/cost-refresh cycles create 256 full moves and
retain the same assignment, objective and invariant values. For 32/128 variables,
bytes fall from 176,128/585,728 to 167,936/577,536 and objects from 1,536 to
1,280. The 128-variable operation takes .001490–.001527 s before and
.001152–.001222 s after. Fresh native collector scopes include initial workspace
capacity and use 173,664/594,352 bytes and 1,328/1,330 objects.

The new 17,198 public-constructor checks pass before and after. They cover edited
and duplicated scope storage, missing ids, empty/duplicate requests, exact errors,
input conversion, independent retained vectors and custom scope call counts.
A separate 62,208-case membership oracle also matches the original semantics.
The updated full suite passes 33,923 assertions including Aqua. All four native
collectors pass nine constructor cases and both complete commit cases. Constructor
allocation profiles agree with the table; one Chairmarks partial-2,048 observation
includes 192 additional bytes/four objects and a .023979 s timing outlier.

All nine diagnostic adapters complete for partial-128. JET remains at zero
findings and AllocCheck at 27 expected possible allocations. The SnoopCompile
adapter records .000015 s inference under its lifecycle; separate load/first/warm
case latency is 1.155/.289/.000127 s. Three GC and lock observations allocate
720,968 bytes each, with no compilation, collection or observed conflicts.
Reachable fixture state stays 4,304 bytes, or 280,832 with the 128 retained moves.
The verified redacted heap snapshot and temporary reports are removed.

## Already sorted partial moves, 2026-10-09

Partial moves now retain their already-owned id and replacement vectors when
the ids are sorted and the collected replacements are a `Vector`. Unsorted ids
and non-vector collections keep the original permutation/indexing path. Caller
inputs and independently retained moves remain separate snapshots.

The baseline is `b5c7e8426f2840c763872090f334cdb95e101cec` in the temporary
LocalSearchSolvers checkout. Other dependency sources and versions match. The
same Julia/CPU/thread settings and three-warmup/five-observation protocol apply;
every measured row has zero compilation, recompilation and collection.

| 128 sorted partial moves | Before bytes / objects | After bytes / objects |
| --- | ---: | ---: |
| 8 ids | 86,088 / 1,283 | 36,936 / 515 |
| 32 ids | 208,968 / 1,283 | 86,088 / 515 |
| 128 ids | 720,968 / 1,283 | 290,888 / 515 |
| 512 ids | 2,671,688 / 1,923 | 1,071,176 / 771 |
| 2,048 ids | 10,536,008 / 1,923 | 4,216,904 / 771 |

The 128-id case takes .0000995–.0001071 s before and .0000537–.0000566 s
after; the 2,048-id case takes .001405–.001492 s before and
.000816–.000876 s after. Unsorted requests retain their previous allocation
totals and overlapping timing ranges. These fixed-work measurements do not
establish application throughput or search quality.

For 256 construct/public-commit/refresh cycles over 32/128 variables, bytes fall
from 413,696/1,437,696 to 167,936/577,536 and objects from 2,816 to 1,280.
The 128-variable cycle takes .001290–.001332 s before and .001106–.001167 s
after. Its assignment, objective and invariant values match. The full-move
control retains 167,936 bytes and 1,280 objects.

All 17,262 constructor checks pass before and after, including 64 additional
checks for matrix/view/range/tuple/generator replacements and retained ownership.
The updated full suite passes 33,987 assertions including Aqua. All four native
collectors pass sorted/unsorted 8/128/2,048-id cases and both complete cycles.
Their constructor allocation profiles match the table. Fresh complete-cycle
scopes agree on 173,664/594,352 bytes and 1,328/1,330 objects. An unsorted
Chairmarks observation retains the previously seen 192-byte/four-object outlier.

All nine native diagnostic adapters complete for sorted partial-128. JET stays
at zero findings; AllocCheck falls from 27 to 25. The lifecycle records .000015 s
inference and 1.157/.308/.0000793 s load/first/warm latency. Three GC and lock
observations allocate 290,888 bytes each with no compilation, collection or
observed conflicts. Reachable fixture/result sizes remain 4,304/280,832 bytes:
the smaller allocation total removes temporary work, not retained output.
Verified redacted heap and temporary reports are removed.

## Owned integer sum refresh, 2026-10-09

The owned solver refreshes machine-Int sum invariants directly instead of
materializing a coefficient/product vector through multi-array mapreduce. The
specialization requires Vector{Int} coefficients and inputs, Int total/target,
and one of the six built-in comparison operators. Machine integer wraparound
makes regrouping exact. Other numeric types and custom operators keep the
original Constraints rebuild extension; no frozen dependency is modified.

The matched baseline is LocalSearchSolvers
184b42113e99f7ede5983cbe495060bb37a61aec. Other sources and package versions
match, including CBLS evaluator 93e83b6 and MetaStrategist 8bcf8b2. Julia 1.13.1
uses CPUs 0/2, two Julia threads and one GC thread. Three complete warmups precede
five observations of each exact operation, with zero compilation/recompilation
throughout.

| 4,096 integer refreshes | Before bytes / objects | After bytes / objects |
| --- | ---: | ---: |
| Full, 32 constraints | 10,485,760 / 262,144 | 0 / 0 |
| Full, 128 constraints | 41,943,040 / 1,048,576 | 0 / 0 |
| Full, 512 constraints | 167,772,160 / 4,194,304 | 0 / 0 |
| Partial, 32 constraints | 655,360 / 16,384 | 0 / 0 |
| Partial, 128 constraints | 655,360 / 16,384 | 0 / 0 |
| Partial, 512 constraints | 655,360 / 16,384 | 0 / 0 |

Full refreshes take .002722–.002770 / .011040–.011469 / .062085–.063798 s
before and .001147–.001208 / .004813–.004953 / .019601–.019737 s after for
32/128/512 constraints. The original 512 case includes .008695–.009259 s GC;
the new integer rows have no collection. Partial refreshes take
.000230–.000252 / .000398–.000414 / .001070–.001118 s before and
.000123–.000124 / .000280–.000287 / .000940–.000947 s after.
Float64 controls retain 10,485,760 / 262,144 for full refreshes and
655,360 / 16,384 for partial refreshes, with overlapping timings.

Complete owned reset-plus-128-step episodes allocate 417,600–417,760 bytes /
5,558–5,559 objects before and 274,240–274,400 / 1,974–1,975 after at 32
variables. At 128 variables, the before range is 1,085,720–1,151,296 /
16,914–16,916, including one byte outlier; the after range is
512,280–512,440 / 2,578–2,579. Final assignments, objectives, invariants and
iteration counts match. These episodes remain infeasible, with errors 14 and
47; their elapsed-time ranges overlap. No episode speed or search-quality
improvement is claimed.

All 5,847 new regression assertions pass before and after, including an
independent BigInt modular-arithmetic oracle, overflow, empty/mismatched inputs,
exact Float32/Float64 fallback bits, custom rebuild call counts and public
weighted constraints with repeated scope ids. The full updated suite passes
39,834 assertions including Aqua.

The complete diagnostic proof is executable in
[invariant_trace_scenarios.jl](invariant_trace_scenarios.jl). Six independent
128-step solves cover seeds 41–43 and 32/128 variables. All 9,263 audit events
and 5,388 candidates, final state identities, and the next 64 UInt64 RNG values
per run match the baseline golden identities. Every available truth audit agrees
on score and feasibility; no event is dropped. Only wall-clock fields are
excluded. The source records each full SHA-256 identity and verifies it before
and after. To reproduce with the qualified dependency environment, include that
file and, for each seed/size, prepare and run invariant_trace_case, then assert
case.verify(fixture,result).

All four native collectors pass all ten refresh/control/episode scenarios.
Chairmarks and the allocation profiler confirm 0 / 0 for each integer refresh;
BenchmarkTools records one 16-byte scalar result at its boundary. Float controls
retain their original allocations. Fresh complete episodes use 274,304 / 1,975
and 512,344 / 2,579; one Chairmarks 32-variable sample uses 257,880 / 1,973.
These lifecycle variations are retained, not treated as a whole-solver zero
allocation result.

All nine diagnostic adapters complete for full integer-128. JET stays at zero
findings and AllocCheck falls from 13 to 9 possible allocations. SnoopCompile
records 12.812747 s inference; load/first/warm latency is
1.062137 / 3.906423 / .005707 s under that adapter lifecycle. Three GC and lock
samples each record 16 bytes / one boundary object, with zero compilation,
collection or observed conflicts. Reachable fixture state stays 190,443 bytes,
or 190,451 with the scalar result. The verified redacted heap snapshot and
temporary reports are removed.

## Built-in integer range scopes, 2026-10-09

UnitRange{Int} and StepRange{Int,Int} ids now use collect to obtain an owned
Vector{Int}, avoiding argument expansion. Other ranges and iterables retain the
original conversion path. The specialization is one method of the existing
private ownership helper; public validation, sorting and replacement ownership
are unchanged.

The matched baseline is e145d7b4e67b11388ab3f0bbef2c39223cdba907. Other versions
and sources match, including MetaStrategist 7eccefa and CBLS evaluator 93e83b6.
Julia 1.13.1 uses CPUs 0/2, two Julia threads and one GC thread. Three complete
warmups precede five observations; compilation, recompilation and GC are zero.

| 128 retained range constructions | Before bytes / objects | After bytes / objects |
| --- | ---: | ---: |
| Meta-variable, 8 ids | 60,488 / 1,539 | 19,528 / 259 |
| Meta-variable, 128 ids | 1,014,856 / 17,283 | 146,504 / 259 |
| Meta-variable, 2,048 ids | 23,017,544 / 657,411 | 2,109,512 / 387 |
| Sorted partial move, 8 ids | 77,896 / 1,795 | 36,936 / 515 |
| Sorted partial move, 128 ids | 1,159,240 / 17,539 | 290,888 / 515 |
| Sorted partial move, 2,048 ids | 25,124,936 / 657,795 | 4,216,904 / 771 |
| Stride-2 partial move, 2,048 ids | 26,169,416 / 723,075 | 4,216,904 / 771 |
| Descending partial move, 2,048 ids | 31,444,040 / 658,947 | 10,536,008 / 1,923 |

The 2,048-id sorted partial case takes .011279–.011657 s before and
.000839–.000912 s after. Descending requests still perform the original
permutation and take .011543–.011740 s before and .001657–.001712 s after.
Vector controls retain their earlier allocation totals and overlapping timings.

For 256 complete range construct/public-commit/refresh cycles at 32/128
variables, bytes fall from 561,152/2,314,240 to 167,936/577,536; objects fall
from 10,240/35,328 to 1,280/1,280. The 128-variable operation takes
.002331–.002388 s before and .001088–.001136 s after. Results preserve
assignments, objectives, invariant costs and owned replacement snapshots.
The new range totals equal the existing vector controls. These fixed-work
figures do not establish application throughput or search quality.

All 5,271 added checks pass before and after, covering positive, negative,
empty, ascending and descending built-in ranges; exact public errors; retained
ownership; full custom range scopes with the same public call count; and
unchanged conversion behavior for other numeric range types. The existing
17,262 constructor checks also pass on both versions. The full updated suite
passes 45,105 assertions including Aqua.

All four native collectors pass 14 representative range/control/complete-cycle
scenarios and agree on constructor allocation totals. Fresh complete cycle
boundaries use 173,664 / 1,328 and 594,352 / 1,330, matching the vector control.
Each raw bundle is released after compact counts are extracted.

All nine native diagnostic adapters complete for partial range-128. JET stays
at zero findings and AllocCheck falls from 26 to 25 possible allocations.
Inference/load/first/warm adapter observations are
.299295 / 1.248579 / .498515 / .000101 s. Three GC and lock samples each
allocate 290,888 bytes with zero compilation, collection or observed conflicts.
Reachable fixture/result sizes stay 2,192/278,720 bytes. The verified redacted
heap snapshot and temporary reports are removed.

The published six-run invariant proof also passes with this package combination:
all 9,263 events, 5,388 candidates, final identities and subsequent RNG values
still match. CBLS's full suite passes 102,836 assertions against the updated
LocalSearchSolvers and MetaStrategist checkouts.

## Short floating sum refresh, 2026-10-09

Owned Float32/Float64 sum invariants with zero, one or two terms now use the
reference scalar multiplication and addition order without materializing a
product vector. The six built-in comparisons and Int/Float32/Float64 targets
are covered. NaN totals, longer sums, mismatched shapes, custom operators and
other numeric types retain the reference rebuild. NaN payload selection can
depend on lowering and register allocation, so the exceptional result always
delegates. No dependency source or solver state layout changes.

The matched baseline is d1c3b81ea7d091909fd187c7d6f808a03392f9a0, with
MetaStrategist 7eccefa and CBLS evaluator 93e83b6 otherwise unchanged. Julia
1.13.1 uses CPUs 0/2, two Julia threads and one GC thread. Three complete warmups
precede five observations; compilation, recompilation and GC are zero.

| 4,096 paired finite refreshes | Before bytes / objects | After bytes / objects |
| --- | ---: | ---: |
| Float32 full, 32 variables | 8,388,608 / 262,144 | 0 / 0 |
| Float32 full, 128 variables | 33,554,432 / 1,048,576 | 0 / 0 |
| Float32 full, 512 variables | 134,217,728 / 4,194,304 | 0 / 0 |
| Float64 full, 32 variables | 10,485,760 / 262,144 | 0 / 0 |
| Float64 full, 128 variables | 41,943,040 / 1,048,576 | 0 / 0 |
| Float64 full, 512 variables | 167,772,160 / 4,194,304 | 0 / 0 |
| Float32 partial, each size | 524,288 / 16,384 | 0 / 0 |
| Float64 partial, each size | 655,360 / 16,384 | 0 / 0 |

Float32 full-128 takes .011531–.011780 s before and .008625–.008678 s after;
Float64 full-128 takes .011344–.011607 s before and .008485–.008842 s after.
Full-512 takes .054894–.057937 / .055105–.055936 s before and
.034512–.035554 / .034035–.034798 s after for Float32 / Float64.
Partial-128 takes .000399–.000411 / .000405–.000416 s before and
.000336–.000343 / .000328–.000339 s after. Small partial-512 changes are not
claimed as application throughput.

For complete owned reset plus 128-step episodes:

| Precision / variables | Before bytes / objects | After bytes / objects |
| --- | ---: | ---: |
| Float32 / 32 | 382,624–382,784 / 5,590–5,591 | 267,936–268,096 / 2,006–2,007 |
| Float32 / 128 | 944,344–944,504 / 17,042–17,043 | 485,592–485,752 / 2,706–2,707 |
| Float64 / 32 | 418,112–418,272 / 5,590–5,591 | 274,752–274,912 / 2,006–2,007 |
| Float64 / 128 | 1,087,768–1,087,928 / 17,042–17,043 | 514,328–514,488 / 2,706–2,707 |

Episode timing ranges overlap, and final errors remain 14/47; these deliberately
infeasible fixed-work fixtures establish neither search quality nor whole-solver
zero allocation. Integer controls stay at zero refresh allocations. Three-term
Float32/Float64 controls retain 10,485,760 / 262,144 for full-32 and
983,040 / 24,576 for partial-32; the full control shows a small timing increase,
so unchanged fallback throughput is not claimed.

All 114,748 added assertions pass on the baseline and final source, including
exceptional payloads, arbitrary bit patterns, empty sums, exact errors, reference
fallbacks, custom rebuild call counts and public weighted repeated-scope truth.
The complete updated suite passes 159,853 assertions including Aqua. A broader
lazy broadcast reduction was rejected after 1,551 of 3,584 normal floating
trials changed result bits; it is absent from the source.

The executable [short_float_trace_scenarios.jl](short_float_trace_scenarios.jl)
covers both precisions, seeds 41–43 and 32/128 variables. All 18,526 audit events,
10,776 candidates, final identities and the next 64 UInt64 RNG values per run
match the twelve baseline golden identities. Independent truth audits agree
and no event is dropped. Only wall-clock fields are excluded. Include the file,
then prepare/run/verify each short_float_trace_case with its precision, size and
seed to reproduce against the qualified dependency environment.

All 88 native collector runs pass. The twelve finite refresh cases, four
complete episode cases and two integer controls each use BenchmarkTools,
Chairmarks, CPU profiling and allocation profiling. Chairmarks and allocation
profiles confirm 0 / 0 for finite refreshes; BenchmarkTools adds one 16-byte
scalar result at its boundary. Fresh complete episodes report
268,000 / 2,007, 485,656 / 2,707, 274,816 / 2,007 and 514,392 / 2,707.
The four longer controls use the first three collectors at 4,096 refreshes;
allocation profiles use sixteen refreshes, yielding 40,960 / 1,024 full and
3,840 / 96 partial. Each bundle is released after extracting compact counts.

All nine diagnostic adapters complete for full Float64-128. JET remains at zero
findings and AllocCheck remains at thirteen possible allocations. SnoopCompile
records 13.662513 s inference; load/first/warm latency is
1.099570 / 4.231554 / .009536 s under that adapter lifecycle. Three GC and lock
samples each record one 16-byte boundary object, with no compilation, collection
or observed conflicts. Reachable fixture state remains 194,555 bytes, or 194,563
with the result. The verified redacted heap snapshot and temporary reports are
removed.

The complete standard Pkg.test("LocalSearchSolvers"; allow_reresolve=false)
also passes all 159,853 assertions with offline resolution after the isolated
Random test-target repairs in MetaStrategist 710b656 and CBLS 8d5e877.
