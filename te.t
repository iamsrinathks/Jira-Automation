The sizer already has an opt-in DECREASE path (`reduceCooldownDays >= windowDays`, step `maxStepDownPerKeyPerPR`, never below in-use). **Do not change any sizing logic** or the existing DECREASE rules. Fix only the gaps below.

## Part A – answer first, no code yet

Reply with the file and line numbers for each:

1. **DRIFT direction.** In `compute`, what does the code do when `live count > terraform count`, and when `live count < terraform count`? Which one is `PENDING_APPLY` and which one is `DRIFT`? Your summary said "DRIFT: live is below Terraform". Confirm whether that's the code or a mistake in the summary.
2. **Cooldown check.** How is "the target stays below current for the whole `reduceCooldownDays`" checked? Does it read more history than `windowDays` when `reduceCooldownDays > windowDays`? If it doesn't, say so.
3. **Fast path.** Can `--fast-check` ever produce a DECREASE?
4. **Holds on a decrease.** Is a DECREASE blocked when there is a stockout hit for the key in the window, when the reservation is attached to a commitment, when the fail-safe fires, or when any key is DRIFT?

Then do Part B. For each item in Part B that Part A shows is already handled, add a test only.

## Part B – changes

1. **CI guard (`ci/check_reservation_change.py`).** Today it rejects every decrease, so every DECREASE PR fails CI.
   - Add `--allow-decrease` (default off) and `--max-step-down N` (required with `--allow-decrease`).
   - With the flag: allow `new < old` only if `old - new <= N` and `new >= 1`. Removing a key is still rejected.
   - A decrease also needs the PR label `reservation-reduce` (use the existing `--labels`). No label → reject.
   - Without the flag: keep today's error message exactly.
   - The CI workflow must decide the flag from the env's policy file: set `--allow-decrease` only if `reduceCooldownDays > 0`, and set `--max-step-down` from `maxStepDownPerKeyPerPR`. No hard-coded env list.

2. **A merged decrease that isn't applied yet must not look like DRIFT.** After a DECREASE PR merges, Terraform says N but Compute Engine still has N + k until HCP Terraform applies. Today that's `live > terraform`, which is DRIFT: it holds all keys, exits 3 and closes the bot PR.
   - Add status `PENDING_DECREASE`: when `live > terraform`, look at the last merged PR from the bot branch for this env/cluster (GitHub API, closed + merged, newest first). If it set this key from `live` down to `terraform`, treat it as `PENDING_DECREASE`: hold this key only, no exit 3, and add a note. Otherwise it stays DRIFT, exactly as today.
   - If the GitHub lookup fails, treat it as DRIFT (fail safe).

3. **Holds for a DECREASE.** Add only the ones Part A shows are missing:
   - a stockout hit for any pool on the key within the window → `REDUCE_HELD`;
   - the reservation is attached to a commitment → `REDUCE_HELD`;
   - `--fast-check` never decreases;
   - the fail-safe and DRIFT stop decreases too.

4. **The PR.** If at least one key is DECREASE, add the label `reservation-reduce`, put `[includes reductions]` in the title, and list the decreases in their own "Reductions" section of the PR body.

5. **Validation.** If `reduceCooldownDays > windowDays` and Part A item 2 shows the extra history is not read, fail validation (exit 4) with a clear message. Don't silently accept it.

## Tests

- CI: a decrease is rejected without the flag; allowed within the step with the flag and label; rejected above the step; rejected without the label; `new = 0` is rejected; key removal is always rejected.
- `PENDING_DECREASE`: matching merged bot PR → this key held, other keys still sized, exit code not 3. No matching PR → DRIFT as today. GitHub error → DRIFT.
- Each hold from Part B item 3.
- `reduceCooldownDays 0` → no DECREASE anywhere (same as today).
- Run the full suite. All 85 existing tests must pass.

## Docs

- README: correct the DRIFT and PENDING_APPLY wording to match the code. Add `PENDING_DECREASE`, the CI flag and the label.
- Add `config/policy-tr1-pre-inline.example.json` with `windowDays 1`, `peakRank 1`, `bufferPct 0`, `surgeHeadroom 0`, `stockoutCapPerKey 0`, `maxStepPerKeyPerPR 10`, `reduceCooldownDays 1`, `maxStepDownPerKeyPerPR 2` and `mode "report"`.

## Rules

- Stdlib only. Don't touch the GitHub auth, bot branch or pool-change trigger code except where item 2 needs a read of merged PRs.
- No `git add .`. Don't commit `wss.crt`, `image.png` or untracked files.
- At the end, list every file changed, the Part A answers and the new tests.
