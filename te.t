In , update the CI workflow that runs
check_reservation_change.py (show me which file it is first):

1. Get the changed files from the PR diff: git diff --name-only
   origin/<base>...HEAD. Run the check once for each changed
   *reservations*.auto.tfvars.json, with --tfvars-path <that repo-relative
   path> and --guard-file ci/reservation-guard.json.
2. Don't take the path from the PR title, body, branch name or labels.
3. Show me how the workflow gets check_reservation_change.py (which repo
   and ref). If it uses main or a tag of ,
   tell me which tag must exist before this works.
4. If the guard file is missing on the base branch, the check must still
   run with no decreases allowed. Read the guard file from the BASE
   branch, not the PR head, so a PR can't loosen its own guard.

Don't commit. List the files you changed.
