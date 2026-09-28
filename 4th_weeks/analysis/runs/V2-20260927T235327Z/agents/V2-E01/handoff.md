# V2-E01 reuse handoff

Conditional artifact reuse: True.

All recorded input/source/config hashes are compared separately in reuse_audit.json. This is a byte/provenance audit, not a statistical review. No tests or statistical analyses were rerun.

- 9814 complete FI and 9786 positive-CBC complete FI are analyst-defined candidate cohort counts, not proof of author-identical data.
- No execution record provides historical output hashes; current output inventory cannot establish that outputs were unchanged since execution.
- Unchanged bytes and a prior zero exit code do not establish statistical validity, correct inference, or original-paper replication.
- analysis_plan status provisional-data-definition-pending is descriptive metadata; unchanged runtime inputs and source hashes determine this narrow reuse audit. Changes to explanatory documents alone do not imply changed statistical inputs.
- Any future change to candidate input, executed code, grouping/coding choices or relevant model configuration requires reassessment and potentially rerun.

## Evidence hashes

- reuse_audit.json: a339a83364204277516d1cc05882aab011149ef0436001e4a4f274e94e55e695
- fi_candidate_provenance.json: 89913acdeb57131eed7c10aedf1e5b0308f161938f166608533a8b983be74b92
- analysis/runs/A01-20260927T210626704130Z/execution.json: d3e6392e1062c9ad7d91dfc7b4d55808e44ccf26c279c05cbe8eab36f97b2379
- analysis/runs/A02-20260927T210626709227Z/execution.json: 933302dab7b07765d4a574e47c325e9e99d196a926f9e25fe04f03c215c20040
- analysis/runs/A03-20260927T210742070434Z/execution.json: e20a16039ccca8a123a4b3514b3ac044fe0c2e0b18571ddb9c5f330f82253fee

## Current environment

R version 4.6.1 (2026-06-24 ucrt) 
survey=4.5

Current output inventory: 39 files; historical output hashes unavailable.

No raw data, existing logs, root documentation, or contracts were modified. Only this task work directory was written.
