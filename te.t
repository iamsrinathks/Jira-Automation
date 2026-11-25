Change the guard workflow in :

1. Copy ci/check_reservation_change.py from the tools repo into this repo
   as ci/check_reservation_change.py (same content, plus a header comment
   with the source commit SHA). Remove the cross-host clone and
   RESERVATION_TOOLS_TOKEN. Add /ci/check_reservation_change.py to
   CODEOWNERS next to the guard file.
2. Trigger: on: pull_request (NOT pull_request_target) for every PR to the
   default branch. No workflow-level paths filter. Checkout with
   fetch-depth: 0.
3. Inside the job: list the changed files from git diff --name-only
   origin/<base>...HEAD and keep those matching
   *reservations*.auto.tfvars.json. If there are none -> pass (exit 0).
4. Bot or human: decide by github.event.pull_request.user.login equal to
   the sizer GitHub App's bot login (put it in an env var at the top of the
   workflow). Bot PR -> run the full check on each file. Human PR -> pass,
   but print "human change - governed by review".
5. Move the limits into ci/reservation-guard.json per path: maxStep,
   maxNewCount, allowNewKeys, allowDecrease, maxStepDown. The guard file
   is still read from the BASE branch. An unlisted path -> increases only,
   with the current defaults (maxStep 3, maxNewCount 20, no new keys
   unless listed, no decreases). Update guard_limit() and the tests.
6. Use one fixed job name, "reservation-guard", so it can be a required
   status check. In the summary, tell me the exact check name to add to
   branch protection.

Don't commit. Run the tests and list the files you changed.
