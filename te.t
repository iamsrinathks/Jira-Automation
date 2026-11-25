ci/check_reservation_change.py will live ONLY in infra-services.
1. Move every test of check_reservation_change.py out of
   img-automation-tools/sizer/tests/test_sizer.py into
   infra-services/ci/tests/test_check_reservation_change.py
   (stdlib unittest, imports ../check_reservation_change.py).
2. In the infra repo, add a step to the reservation-guard job that runs
   these tests first: python3 -m unittest discover -s ci/tests
   (it fails the check if a test fails).
3. Change the header of the infra copy to: "Source of truth: this repo.
   Used by the Reservation sizer guard workflow."
   Remove the source SHA / sha256 lines.
4. In the tools repo, remove ci/ and any reference to it, and make sure
   nothing in sizer/ or the Dockerfile imports or copies it.
5. Run both suites and tell me the test count in each (the two together
   should be 116). Don't commit.
