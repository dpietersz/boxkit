"""Safety gates: no container mutation before consent and package verification."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/install-citrix-workspace.sh"


class CitrixInstallTests(unittest.TestCase):
  def run_helper(self, *args):
    with tempfile.TemporaryDirectory() as directory:
      root = Path(directory)
      # Real container operations must never be reached by these invalid inputs.
      stub = root / "distrobox"
      stub.write_text('#!/bin/sh\necho MUTATION_ATTEMPTED >&2\nexit 99\n')
      stub.chmod(0o755)
      env = dict(os.environ, HOME=directory, PATH=f"{directory}:{os.environ['PATH']}")
      result = subprocess.run(["bash", str(SCRIPT), *args], env=env, text=True,
                              capture_output=True)
      self.assertNotIn("MUTATION_ATTEMPTED", result.stderr)
      return result

  def test_requires_explicit_license_consent(self):
    result = self.run_helper()
    self.assertNotEqual(result.returncode, 0)
    self.assertIn("--accept-license", result.stderr)

  def test_missing_installer_explains_download_requirement(self):
    result = self.run_helper("--accept-license", "/nonexistent/citrix.deb")
    self.assertNotEqual(result.returncode, 0)
    self.assertIn("Installer not found", result.stderr)

  def test_rejects_corrupt_package_before_entering_container(self):
    with tempfile.NamedTemporaryFile(suffix=".deb") as package:
      package.write(b"not an official Citrix package")
      package.flush()
      result = self.run_helper("--accept-license", package.name)
    self.assertNotEqual(result.returncode, 0)
    self.assertIn("checksum", result.stderr.lower())

  def test_rejects_extra_arguments(self):
    result = self.run_helper("--accept-license", "/tmp/package.deb", "unexpected")
    self.assertNotEqual(result.returncode, 0)
    self.assertIn("Usage:", result.stderr)


if __name__ == "__main__":
  unittest.main()
