Add a CHG lock and PR outputs to the reservation sizer, so prod PRs are raised by day and merged
only by the Harness `reservation-merge` pipeline in the CHG window (22:00 Europe/London).
Do NOT change any sizing logic (pool_layers, key_target, compute, coverage audit).

## The flow this supports
1. Harness `reservation-sizer` runs the sizer (morning + fast-check). The sizer raises/updates the bot PR.
2. A Harness step after it (not the sizer) creates a ServiceNow CHG that records the PR head SHA,
   then adds two labels to the PR: `chg-locked` and `chg:<CHG number>`.
3. From that moment the PR must never change. Harness `reservation-merge` merges it at 22:00 only
   if the head SHA still equals the SHA on the CHG.

## Sizer changes
1. Lock label
   - New optional policy key "prLockLabel" (default "chg-locked"); validate it is a non-empty string.
   - Before ANY write to the bot PR, look it up with github.open_pr(repo, branch).
   - If it carries the lock label:
     - do not push, reset the branch, edit title/body, add labels, or close it;
     - this covers raise_pr, close_stale on "no change needed", close_stale on fail-safe
       (closePrOnFailsafe), close_stale on DRIFT, and the dry-run/live mode-switch close in github_pr.py;
     - still compute everything and write report.json, proposed.tfvars.json and pr_body.md;
     - log NOTICE "bot PR #<n> is locked for <chg label or 'CHG'> - changes deferred until it is merged",
       with the keys that would have changed;
     - add report["pr"]["locked"] = true and report["deferred_changes"] = [keys with INCREASE/CREATE];
     - exit codes stay as they are today (0, or 3 for holds with noStacking).
   - On fail-safe with a locked PR: do not close it, log WARNING "fail-safe while PR #<n> is locked for
     <CHG> - review before the window"; exit 2 as today.
   - A PR without the label behaves exactly as today.
2. PR outputs for Harness
   - Write <out-dir>/pr.json on every run (also report mode, with nulls):
     {"number", "url", "head_sha", "branch", "base", "pushed" (true only if this run pushed a commit),
      "locked", "chg" (the number from a `chg:<n>` label, else null), "mode", "trigger", "run_id",
      "snapshot", "changed_keys"}.
   - After raise_pr, get number + head SHA with open_pr() (keep raise_pr's signature and return
     value backward compatible).
   - Copy the same object into report.json under "pr".
3. Hold wording
   - PENDING_APPLY text: "branch says N, Compute Engine has M - merged and not applied yet
     (normal until the CHG-window apply), or the apply failed. If it failed with a stock-out, set
     <field> to <step_back> in a human PR". Status names do not change.

## Tests (all existing tests must still pass on Python 3.9; use the FakeGitHub in test_sizer.py,
## give it labels + head sha on open_pr)
1. Locked PR + new INCREASE in live mode -> raise_pr not called, NOTICE logged, deferred_changes set, exit 0.
2. Locked PR + nothing to change -> close_bot_pr not called.
3. Locked PR + fail-safe -> not closed, WARNING logged, exit 2.
4. Locked PR + DRIFT -> not closed, exit 3.
5. Locked PR + mode switch dry-run <-> live -> not closed (test github_pr.raise_pr is never reached).
6. Custom prLockLabel ("cab-frozen") is respected; the default label is then ignored.
7. pr.json: correct fields after a raise (pushed=true, head_sha set), after an unchanged run
   (pushed=false), in report mode (nulls), and chg parsed from a `chg:CHG0012345` label.
8. Unlocked PR: behaviour identical to before (existing tests cover this; add one explicit check).

## Docs and constraints
- how_it_works.md: add "CHG flow" to section 8 (lock label, pr.json, who merges, when).
- stdlib only. Do not touch sizing. Do not add merge capability to the sizer: merging is Harness only.
- Show me git diff --stat, the test count, and pr.json from a fixture run (locked and unlocked).
