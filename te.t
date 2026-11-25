PENDING_DECREASE lookup: does it check the last merged bot PR, and does a GitHub error fall back to DRIFT?
CI label rule: does a decrease need the reservation-reduce label? Are new = 0 and key removal still rejected?
Second stockout fetch:
Is it skipped when reduceCooldownDays is 0? If not, it's extra Logging API calls for nothing.
If that fetch fails, are decreases held (fine) or does it trigger the fail-safe (too strict)?
The fast path drops a pending decrease: if the daily run put a decrease in the open bot PR and a fast run then updates that PR, the decrease disappears until the next daily run. That's safe (it errs towards more capacity), but the PR body should say so.
The design question: where does CI get the policy file?
--policy FILE means the CI on the Terraform repo must read the sizer policy.
But the policy now lives in the ACM addon Helm values (lcp-gcp-gke-acm-addons), so CI on the other repo can't see it unless you copy it.
Don't let the bot's PR supply the step size. The bot would be setting its own limit.
Simplest option: set --allow-decrease --max-step-down 2 in the Terraform repo's CI, per env, and only for tr1-pre for now. Keep it matching the Helm values by hand. That's two places, but each is human-owned.
