grep -rn "applyGraceMinutes\|apply_mismatch\|applyMismatch\|key_changes" sizer/ ci/ | cut -c1-120
git diff --stat
