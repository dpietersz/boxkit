"""Behavior tests for the user-side Insta360 Wine launcher.

Wine is replaced with tiny shell commands so these tests require only Python's
standard library and never create a real Wine prefix.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
LAUNCHER = REPO / "scripts" / "insta360-studio"


class Insta360StudioTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.home = self.root / "home with spaces"
        (self.home / "dev").mkdir(parents=True)
        self.data_home = self.root / "data with spaces"
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        self.log = self.root / "wine.log"
        fake_wine = self.bin_dir / "wine"
        fake_wine.write_text(
            "#!/usr/bin/env bash\n"
            "set -eu\n"
            "printf '%s' \"$(basename \"$0\")\" >> \"$INSTA360_TEST_LOG\"\n"
            "for arg in \"$@\"; do printf ' <%s>' \"$arg\" >> \"$INSTA360_TEST_LOG\"; done\n"
            "printf ' qt=%s scale=%s overrides=%s prefix=%s arch=%s\\n' "
            "\"${QT_ENABLE_HIGHDPI_SCALING-unset}\" \"${QT_SCALE_FACTOR-unset}\" "
            "\"${WINEDLLOVERRIDES-unset}\" \"${WINEPREFIX-unset}\" \"${WINEARCH-unset}\" >> \"$INSTA360_TEST_LOG\"\n"
            "if [ \"$(basename \"$0\")\" = wineboot ]; then\n"
            "  mkdir -p \"$WINEPREFIX/drive_c\" \"$WINEPREFIX/dosdevices\"\n"
            "fi\n",
            encoding="utf-8",
        )
        fake_wine.chmod(0o755)
        for name in ("wineboot", "winecfg"):
            (self.bin_dir / name).symlink_to(fake_wine.name)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def environment(self, **extra: str) -> dict[str, str]:
        env = os.environ.copy()
        env.update(
            {
                "HOME": str(self.home),
                "XDG_DATA_HOME": str(self.data_home),
                "INSTA360_WINE_BIN_DIR": str(self.bin_dir),
                "INSTA360_TEST_LOG": str(self.log),
                "PATH": f"{self.bin_dir}:{env['PATH']}",
                "DISPLAY": "",
                "WAYLAND_DISPLAY": "",
            }
        )
        env.update(extra)
        return env

    def run_main(self, *arguments: str, root: bool = False, **extra: str) -> subprocess.CompletedProcess[str]:
        uid = "0" if root else "1000"
        command = (
            'source "$1"; shift; '
            f'current_uid() {{ printf {uid}; }}; '
            'main "$@"'
        )
        return subprocess.run(
            ["bash", "-c", command, "bash", str(LAUNCHER), *arguments],
            text=True,
            capture_output=True,
            env=self.environment(**extra),
            check=False,
        )

    @property
    def prefix(self) -> Path:
        return self.data_home / "insta360-studio" / "prefix"

    def test_root_is_refused_but_help_is_available(self) -> None:
        refused = self.run_main("--setup", root=True)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("refusing to run Wine as root", refused.stderr)
        self.assertFalse(self.log.exists())

        help_result = subprocess.run(
            ["bash", str(LAUNCHER), "--help"], text=True, capture_output=True, check=False
        )
        self.assertEqual(help_result.returncode, 0)
        self.assertIn("Usage:", help_result.stdout)

    def test_invalid_launcher_options_are_rejected(self) -> None:
        for arguments in (("--setup", "extra"), ("--install",), ("--unknown",)):
            with self.subTest(arguments=arguments):
                result = self.run_main(*arguments)
                self.assertEqual(result.returncode, 2)
                self.assertIn("Usage:", result.stderr)

    def test_missing_or_bad_installer_never_executes_wine(self) -> None:
        missing = self.run_main("--install", "/does/not/exist.exe")
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("not found", missing.stderr)
        self.assertFalse(self.log.exists())

        installer = self.root / "installer.exe"
        installer.write_bytes(b"not the approved installer")
        bad_hash = self.run_main("--install", str(installer))
        self.assertNotEqual(bad_hash.returncode, 0)
        self.assertIn("SHA-256", bad_hash.stderr)
        self.assertFalse(self.log.exists())

    def test_missing_studio_prints_install_instructions(self) -> None:
        result = self.run_main()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Insta360 Studio is not installed", result.stderr)
        self.assertIn("--install /absolute/path", result.stderr)

    def test_d_mapping_is_idempotent_and_never_clobbers_conflicts(self) -> None:
        first = self.run_main("--setup")
        self.assertEqual(first.returncode, 0, first.stderr)
        mapping = self.prefix / "dosdevices" / "d:"
        self.assertTrue(mapping.is_symlink())
        self.assertEqual(mapping.resolve(), (self.home / "dev").resolve())

        again = self.run_main("--setup")
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(mapping.resolve(), (self.home / "dev").resolve())

        mapping.unlink()
        other = self.root / "other media"
        other.mkdir()
        mapping.symlink_to(other)
        conflict = self.run_main("--setup")
        self.assertNotEqual(conflict.returncode, 0)
        self.assertIn("refusing to replace existing D: mapping", conflict.stderr)
        self.assertEqual(mapping.resolve(), other.resolve())

    def test_setup_and_launch_apply_wine_settings_with_whitespace_safe_paths(self) -> None:
        setup = self.run_main("--setup")
        self.assertEqual(setup.returncode, 0, setup.stderr)
        executable = self.prefix / "drive_c" / "Program Files" / "Insta360 Studio" / "Insta360 Studio.exe"
        executable.parent.mkdir(parents=True)
        executable.touch()

        launch = self.run_main(
            "--", "clip with spaces.insv", QT_SCALE_FACTOR="2", WINEPREFIX="/should/not/be/used", WINEARCH="win32"
        )
        self.assertEqual(launch.returncode, 0, launch.stderr)
        log = self.log.read_text(encoding="utf-8")
        self.assertIn("winecfg <-v> <win11>", log)
        self.assertIn("<LogPixels> </t> <REG_DWORD> </d> <144>", log)
        self.assertIn("<144>", log)
        self.assertIn("Insta360 Studio.exe> <clip with spaces.insv>", log)
        self.assertIn("qt=0 scale=unset overrides=winemenubuilder.exe,quick-look.exe,quick-look-daemon.exe=d", log)
        self.assertIn(f"prefix={self.prefix} arch=win64", log)
        self.assertIn("quick-look.exe,quick-look-daemon.exe=d;mscoree,mshtml=d", log)
        self.assertEqual(log.count("wineboot <-i>"), 1)
        self.assertNotIn("wineboot <-u>", log)
        self.assertEqual(log.count("winecfg <-v>"), 1)

    def test_launch_honors_prefix_lock(self) -> None:
        import fcntl
        executable = self.prefix / "drive_c" / "Program Files" / "Insta360 Studio" / "Insta360 Studio.exe"
        executable.parent.mkdir(parents=True)
        executable.touch()
        with Path(str(self.prefix) + ".lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            for args in ((), ("--setup",)):
                result = self.run_main(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("already using", result.stderr)
                self.assertFalse(self.log.exists())

    def test_no_nvidia_leaves_mesa_discovery_alone(self) -> None:
        command = 'source "$1"; configure_nvidia_vulkan; printf "%s" "${VK_DRIVER_FILES-unset}"'
        env = self.environment(INSTA360_NVIDIA_DEVICE=str(self.root / "absent-device"))
        env.pop("VK_DRIVER_FILES", None)
        result = subprocess.run(["bash", "-c", command, "bash", str(LAUNCHER)],
                                env=env, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "unset")

    def test_nvidia_manifest_repair_is_prefix_local_and_optional(self) -> None:
        icd_dir = self.root / "icd"
        icd_dir.mkdir()
        manifest = icd_dir / "nvidia_icd.json"
        manifest.write_text(
            json.dumps({"file_format_version": "1.0.0", "ICD": {"library_path": "/missing/libc.so.6"}}),
            encoding="utf-8",
        )
        device = self.root / "nvidiactl"
        device.touch()
        command = (
            'source "$1"; PREFIX="$2"; '
            'INSTA360_NVIDIA_DEVICE="$3" INSTA360_VULKAN_ICD_DIRS="$4" '
            'configure_nvidia_vulkan; printf "%s|%s|%s" "${VK_DRIVER_FILES-unset}" '
            '"${__NV_PRIME_RENDER_OFFLOAD-unset}" "${__GLX_VENDOR_LIBRARY_NAME-unset}"'
        )
        result = subprocess.run(
            ["bash", "-c", command, "bash", str(LAUNCHER), str(self.prefix), str(device), str(icd_dir)],
            text=True,
            capture_output=True,
            env=self.environment(),
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        repaired = self.prefix / "vulkan" / manifest.name
        self.assertEqual(result.stdout, f"{repaired}|1|nvidia")
        self.assertTrue(repaired.is_file())
        self.assertEqual(json.loads(manifest.read_text())["ICD"]["library_path"], "/missing/libc.so.6")
        replacement = json.loads(repaired.read_text())["ICD"]["library_path"]
        self.assertIn(replacement, ("libc.so.6", "/usr/lib64/libc.so.6"))


if __name__ == "__main__":
    unittest.main()
