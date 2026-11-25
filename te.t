Add an "apply-mismatch" check to --fast-check. Do NOT change sizing.

1. Read the tfvars from main (as today) and the live reservations
   (as today). For each key where terraform != live (skip NOT_READY and
   commitment-attached keys):
   - find the newest commit on main that changed this key, and the PR
     it came from (if any), bot or human;
   - if that commit is older than applyGraceMinutes (new policy key,
     default 60, int >= 15), it's an apply mismatch.
2. On a mismatch:
   - log one ERROR line: {"event":"apply_mismatch","key":..,
     "terraform":..,"live":..,"pr":..,"minutes_since_merge":..};
   - GitHub Issue (if Issues are enabled on the repo):
     - look for an OPEN issue with label "reservation-apply-mismatch"
       and the body marker <!-- apply-mismatch:<env>-<cluster> -->;
     - none -> create it (one issue per env/cluster, not per key);
       one exists -> edit its body (no new issue, no new comment unless
       the set of failed keys changed);
     - title: "[apply-mismatch] <env>/<cluster>: <n> reservation keys
       not applied";
     - body: start with applyMismatchMention, link the PR or commit that
       changed each key, then list every key in that change:
         ✅ applied (terraform == live) - "leave it";
         ❌ not applied - live, terraform,
            "Make green: set to <live>" (recommended in prod) and
            "Retry smaller: set to <step_back_to>"
            (step_back_to = live + max(1, (terraform - live) // 2)).
       End with: "Raise a human PR from your own branch. Change only the
       ❌ keys. Do not revert the whole PR."
   - Issues disabled -> comment on the merged PR instead (same text,
     marker <!-- apply-mismatch:<key> -->, comments are allowed on merged
     PRs unless locked).
   - When a later run finds terraform == live for every key in an open
     issue -> comment "Resolved: all keys applied" and close it.
   - exit 3. Raise no new PR.
3. Decreases: terraform < live with a matching merged decrease =
   PENDING_DECREASE; after applyGraceMinutes it's also a mismatch, with
   the same comment ("Make green: set to <live>").
4. The GitHub lookup or comment fails -> log a WARNING and still exit 3.
5. Tests: inside the grace period -> nothing; after it -> ERROR + one
   comment; second run -> no duplicate; a partial apply (2 keys OK,
   1 failed) -> the comment lists all 3 correctly with the values above;
   a human PR that failed to apply -> also detected; the mention is at
   the start when set; a GitHub error -> exit 3 with a warning.
6. README: the event name "apply_mismatch" (for a later log-based
   alert), and the runbook: "ZONE_RESOURCE_POOL_EXHAUSTED -> set the
   failed key to its live count (make green) or to step_back_to. Never
   revert the whole PR on a partial apply."

Don't commit. Run the full suite and list the files you changed.
