Part A looks right. For Part B, apply these rules as well:

1. Stockout hold for DECREASE: fetch stockout hits from hist_start (the
   same start as the cooldown history), not only the normal window. Use
   these hits ONLY for the decrease hold. The increase "unmet" logic keeps
   the normal window - don't change sizing.
2. Any stockout hit for any pool on the key inside the cooldown ->
   REDUCE_HELD, even if stockoutCapPerKey is 0.
3. DRIFT on any key blocks every DECREASE, whatever noStacking is set to.
   Don't change how increases behave with noStacking false.
4. Fast path: after compute, change every DECREASE row to REDUCE_HELD with
   the note "fast path never reduces" and proposed = current. If nothing
   is left to change, raise no PR.
5. PENDING_DECREASE: keep it out of holds (no exit 3). Show it in the PR
   body and report.json, and show it as "pending" in the coverage audit,
   not "partial".

Add tests for each of these, plus: cooldown coverage below
minDataCoverage -> no reduction and exit 0, not 2.
