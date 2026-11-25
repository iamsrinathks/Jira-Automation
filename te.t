The checkpoint restore did not remove the apply-mismatch feature.
Remove it completely, by editing in the editor (no terminal scripts):
- reservation_sizer.py: DEFAULT_POLICY keys applyGraceMinutes and
  applyMismatchMention (~117-118), their validation (~264-268),
  report_apply_mismatch, resolve_apply_mismatch, apply_mismatch_check
  (~1902-1984), and the fast-check hook (~2051-2055) so --fast-check
  runs exactly as before.
- github_pr.py: key_changes() and any issue/comment helpers added for
  this feature.
- tests/test_sizer.py: the FakeGitHub apply-mismatch extension and all
  apply-mismatch tests.
- README_reservation_sizer_v1.md: the apply-mismatch section (~127-136).
Keep everything else exactly as it is (decreases, reduce holds,
PENDING_DECREASE, guard, fast-path no-reduce rule).
Then run the full suite: expect 116 tests, all OK. Show git status
--short. Don't commit.


find sizer -name __pycache__ -prune -exec rm -rf {} +
grep -rn "applyGraceMinutes\|apply_mismatch\|applyMismatch\|key_changes" sizer/ ci/
cd sizer && python3 -m unittest discover -s tests
