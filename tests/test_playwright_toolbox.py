"""Image smoke tests. Run with PLAYWRIGHT_TEST_IMAGE=playwright-toolbox:test.

A fresh, non-root HOME and direct Node entrypoint catch browser paths that
only work after sourcing /etc/profile.d/playwright.sh or using a warm cache.
"""
import json
import os
import subprocess
import unittest


@unittest.skipUnless(os.environ.get("PLAYWRIGHT_TEST_IMAGE"),
                     "Set PLAYWRIGHT_TEST_IMAGE to run container smoke tests")
class PlaywrightToolboxTests(unittest.TestCase):
  def test_browsers_launch_without_login_shell_or_user_cache(self):
    for browser, options in (
      ("chromium", {}),
      ("chromium", {"channel": "chromium"}),
      ("firefox", {}),
      ("webkit", {}),
    ):
      with self.subTest(browser=browser, options=options):
        # Arguments use JSON, not shell interpolation. No external site needed.
        script = """
const assert = require('node:assert/strict');
const playwright = require('/usr/lib/node_modules/playwright');
(async () => {
  const browser = await playwright[process.argv[1]].launch(
    JSON.parse(process.argv[2])
  );
  try {
    const page = await browser.newPage();
    await page.setContent('<title>toolbox smoke test</title>');
    assert.equal(await page.title(), 'toolbox smoke test');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
"""
        result = subprocess.run([
          "podman", "run", "--rm", "--network=none", "--user=1000:1000",
          "--env=HOME=/tmp/playwright-test", os.environ["PLAYWRIGHT_TEST_IMAGE"],
          "/usr/bin/node", "-e", script, browser, json.dumps(options),
        ], text=True, capture_output=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
  unittest.main()
