import json
import os
import socket
import subprocess
import sys
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = (REPOSITORY_ROOT / "VERSION").read_text(encoding="utf-8").strip()


class ApplicationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            cls.port = listener.getsockname()[1]

        environment = os.environ.copy()
        environment["PORT"] = str(cls.port)
        cls.process = subprocess.Popen(
            [sys.executable, "app.py"],
            cwd=REPOSITORY_ROOT,
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                with urllib.request.urlopen(cls.url("/health"), timeout=0.5):
                    return
            except (OSError, urllib.error.URLError):
                if cls.process.poll() is not None:
                    output = cls.process.stdout.read() if cls.process.stdout else ""
                    raise RuntimeError(f"application stopped during startup: {output}")
                time.sleep(0.1)

        cls.process.terminate()
        raise RuntimeError("application did not become ready within five seconds")

    @classmethod
    def tearDownClass(cls):
        cls.process.terminate()
        try:
            cls.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            cls.process.kill()
            cls.process.wait(timeout=3)

    @classmethod
    def url(cls, path):
        return f"http://127.0.0.1:{cls.port}{path}"

    def request(self, path):
        with urllib.request.urlopen(self.url(path), timeout=2) as response:
            return response.status, response.headers.get_content_type(), response.read()

    def test_home_page_contains_visible_version(self):
        status, content_type, body = self.request("/")
        self.assertEqual(status, 200)
        self.assertEqual(content_type, "text/html")
        self.assertIn(EXPECTED_VERSION.encode(), body)

    def test_health_endpoint(self):
        status, content_type, body = self.request("/health")
        self.assertEqual(status, 200)
        self.assertEqual(content_type, "application/json")
        self.assertEqual(json.loads(body), {"status": "ok", "version": EXPECTED_VERSION})

    def test_version_endpoint(self):
        status, _, body = self.request("/version")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["version"], EXPECTED_VERSION)

    def test_unknown_endpoint_returns_404(self):
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(self.url("/does-not-exist"), timeout=2)
        self.assertEqual(error.exception.code, 404)
        self.assertEqual(json.loads(error.exception.read()), {"error": "not found"})


if __name__ == "__main__":
    unittest.main()
