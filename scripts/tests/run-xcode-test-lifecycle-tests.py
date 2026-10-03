#!/usr/bin/env python3
"""Exercise the real wrapper with disposable stubs; never run Xcode or a Simulator."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "xcode-test.sh"


class PostTestLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ohana-xcode-lifecycle-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        scripts = self.root / "scripts"
        (scripts / "lib").mkdir(parents=True)
        scheme = self.root / "Ohana.xcodeproj/xcshareddata/xcschemes/OhanaUITests.xcscheme"
        scheme.parent.mkdir(parents=True)
        scheme.write_text("<Scheme/>\n")
        shutil.copyfile(SOURCE, scripts / "xcode-test.sh")
        (scripts / "lib/local-build-environment.sh").write_text("""
OHANA_TEST_SIMULATOR_NAME_FIXED='iPhone 17 Tests'
OHANA_LOCAL_BUILD_CACHE_ROOT="${FIXTURE_ROOT}/cache"
OHANA_TEST_DERIVED_DATA_PATH="${FIXTURE_ROOT}/cache/DerivedData"
OHANA_TEST_RESULT_ROOT="${FIXTURE_ROOT}/cache/TestResults"
OHANA_TEST_FAILURE_RETENTION_COUNT=3
OHANA_TEST_FAILURE_RETENTION_DAYS=7
OHANA_MINIMUM_FREE_GIB=20
ohana_assert_test_simulator_udid() { [[ "$1" == 'TEST-UDID' ]] || return 64; }
ohana_available_disk_kib() {
  if [[ -f "${FIXTURE_ROOT}/tested" ]]; then
    printf '%s\\n' "${FIXTURE_AFTER_FREE_KIB}"
  else
    printf '%s\\n' "$((64 * 1024 * 1024))"
  fi
}
ohana_path_size_kib() { printf '0\\n'; }
""")
        self.executable(scripts / "test-simulator.sh", """
printf 'test:%s\\n' "${OHANA_TEST_ACTION}" >> "${FIXTURE_ROOT}/calls"
touch "${FIXTURE_ROOT}/tested"
exit "${FIXTURE_TEST_EXIT}"
""")
        self.executable(scripts / "cleanup-local-build-storage.sh", """
printf 'cleanup:%s\\n' "$2" >> "${FIXTURE_ROOT}/calls"
if [[ "${OHANA_KEEP_TEST_SIMULATOR_BOOTED:-0}" == '1' ]]; then
  echo 'Refusing test app cache cleanup while iPhone 17 Tests is Booted.' >&2
  exit 75
fi
if [[ "${FIXTURE_CLEANUP_EXIT}" != '0' ]]; then exit "${FIXTURE_CLEANUP_EXIT}"; fi
echo 'No conservative cleanup candidates found.'
""")
        # An accidental real-tool dependency must fail without touching devices.
        bin_directory = self.root / "bin"
        bin_directory.mkdir()
        for tool in ["xcodebuild", "xcrun"]:
            self.executable(bin_directory / tool, "echo 'Unexpected real Xcode dependency' >&2\nexit 99\n")

    @staticmethod
    def executable(path, source):
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + source)
        path.chmod(0o755)

    def run_wrapper(self, *, keep_booted=False, test_exit=0, cleanup_exit=0,
                    free_gib=32, build_only=False, device="TEST-UDID"):
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith("OHANA_") and key not in ["DESTINATION", "SCHEME"]}
        environment.update({
            "PATH": str(self.root / "bin") + os.pathsep + environment.get("PATH", ""),
            "FIXTURE_ROOT": str(self.root), "FIXTURE_TEST_EXIT": str(test_exit),
            "FIXTURE_CLEANUP_EXIT": str(cleanup_exit),
            "FIXTURE_AFTER_FREE_KIB": str(free_gib * 1024 * 1024),
            "SCHEME": "OhanaUITests", "OHANA_TEST_SIMULATOR_UDID": device,
            "OHANA_KEEP_TEST_SIMULATOR_BOOTED": "1" if keep_booted else "0",
        })
        arguments = ["--build-for-testing"] if build_only else ["--only-testing", "OhanaUITests/Case/testOne"]
        result = subprocess.run(["bash", str(self.root / "scripts/xcode-test.sh"), *arguments],
                                cwd=self.root, env=environment, capture_output=True, text=True)
        calls_file = self.root / "calls"
        calls = calls_file.read_text().splitlines() if calls_file.exists() else []
        return result, calls

    def test_successful_shutdown_run_still_cleans_test_app_cache(self):
        result, calls = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls, ["test:build-then-test", "cleanup:test-app-cache"])

    def test_successful_kept_booted_run_preserves_evidence_without_false_failure(self):
        result, calls = self.run_wrapper(keep_booted=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls, ["test:build-then-test"])
        self.assertIn("Deferring Tests cache cleanup", result.stdout)

    def test_failed_test_is_not_hidden_by_kept_booted_mode(self):
        result, calls = self.run_wrapper(keep_booted=True, test_exit=65)
        self.assertEqual(result.returncode, 65)
        self.assertEqual(calls, ["test:build-then-test"])

    def test_failed_shutdown_test_still_returns_its_failure(self):
        result, calls = self.run_wrapper(test_exit=65)
        self.assertEqual(result.returncode, 65)
        self.assertEqual(calls, ["test:build-then-test", "cleanup:test-app-cache"])

    def test_real_cleanup_failure_is_not_suppressed(self):
        result, calls = self.run_wrapper(cleanup_exit=75)
        self.assertEqual(result.returncode, 75)
        self.assertEqual(calls, ["test:build-then-test", "cleanup:test-app-cache"])

    def test_booted_storage_pressure_stops_without_unsafe_cleanup(self):
        result, calls = self.run_wrapper(keep_booted=True, free_gib=10)
        self.assertEqual(result.returncode, 75)
        self.assertEqual(calls, ["test:build-then-test"])
        self.assertIn("below 20 GiB", result.stderr)

    def test_shutdown_storage_pressure_uses_the_reviewed_narrow_scopes(self):
        result, calls = self.run_wrapper(free_gib=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls, ["test:build-then-test", "cleanup:test-app-cache", "cleanup:test-transient-cache"])

    def test_build_only_does_not_clean_simulator_cache(self):
        result, calls = self.run_wrapper(keep_booted=True, build_only=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls, ["test:build-for-testing"])

    def test_non_test_device_is_rejected_before_any_execution(self):
        result, calls = self.run_wrapper(device="DOGFOOD-UDID")
        self.assertEqual(result.returncode, 64)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
