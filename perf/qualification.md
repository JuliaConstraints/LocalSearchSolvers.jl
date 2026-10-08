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
