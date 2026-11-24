1. Both CronJobs: pod annotation sidecar.istio.io/inject: "false"; concurrencyPolicy: Forbid;
   timeZone: Europe/London; startingDeadlineSeconds: 300; activeDeadlineSeconds 2700 (full) / 600 (fast).
2. Schedules that never overlap: full "13 7 * * *", fast "5,20,35,50 0-6,8-23 * * *" (values, overridable).
3. A suspend value (default false) mapped to .spec.suspend on both CronJobs.
4. Pod security for Gatekeeper deny mode: runAsNonRoot, readOnlyRootFilesystem, drop ALL caps,
   emptyDir mounted at /tmp/sizer-out with OUT_DIR pointing there, requests/limits, nodeSelector for
   the system pool, priorityClassName value.
5. GitHub auth via GITHUB_APP_SECRET (Secret Manager through Workload Identity); no Kubernetes Secret.
6. Image pinned by digest in values; document image v0.0.5 = sizer 2.1.0.
7. A CI check: helm template per cluster values file, extract policy.json from the ConfigMap and run
   the sizer's load_policy() against it with the same image version; fail on any error.
List anything you could not verify (NetworkPolicy, namespace ownership, Workload Identity binding).
