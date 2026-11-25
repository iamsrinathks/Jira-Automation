Option 1. Details:

1. Add ci/reservation-guard.json in the Terraform repo, keyed by the
   tfvars path the PR changes (not the branch name), e.g.
   {"envs/tr1-pre/svp01/ew2/reservations.auto.tfvars.json":
     {"allowDecrease": true, "maxStepDown": 2}}
   A path that isn't listed -> no decreases allowed (fail closed).
   Put a comment field in each entry pointing to the matching Helm values
   file in lcp-gcp-gke-acm-addons.
2. check_reservation_change.py: add --guard-file. It looks up every
   changed tfvars path and applies --allow-decrease / --max-step-down from
   that entry. Keep the explicit flags for local use. If both are given,
   the stricter value wins.
3. Add a CODEOWNERS entry so ci/reservation-guard.json needs
   platform-team approval.
4. Only tr1-pre is listed for now.
5. Tests: path listed and within the step -> pass; path not listed ->
   decrease rejected; step above the guard -> rejected; both guard and
   flag given -> the stricter one wins; a malformed guard file -> reject
   all decreases.
6. Also add the 2 missing tests: the second stockout fetch fails ->
   every decrease is REDUCE_HELD and exit 0; a fast run that drops a
   decrease -> the PR body note names the dropped keys.

Don't commit. Run the full suite and list the files you changed.
