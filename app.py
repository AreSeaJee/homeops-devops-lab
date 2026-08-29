import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


APP_NAME = "HomeOps DevOps Lab"
HOST = "0.0.0.0"
PORT = int(os.environ.get("PORT", "8080"))
VERSION = (Path(__file__).parent / "VERSION").read_text(encoding="utf-8").strip()


class RequestHandler(BaseHTTPRequestHandler):
    def send_body(self, status, content_type, body):
        encoded_body = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded_body)))
        self.end_headers()
        self.wfile.write(encoded_body)

    def do_GET(self):
        if self.path == "/":
            body = f"""<!doctype html>
<html lang="de">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{APP_NAME}</title>
  </head>
  <body>
    <main>
      <h1>{APP_NAME}</h1>
      <p>Die Demo-App läuft.</p>
      <p>Version: <strong>{VERSION}</strong></p>
    </main>
  </body>
</html>
"""
            self.send_body(200, "text/html", body)
            return

        if self.path == "/health":
            body = json.dumps({"status": "ok", "version": VERSION})
            self.send_body(200, "application/json", body)
            return

        if self.path == "/version":
            body = json.dumps({"name": APP_NAME, "version": VERSION})
            self.send_body(200, "application/json", body)
            return

        self.send_body(404, "application/json", json.dumps({"error": "not found"}))

    def log_message(self, format, *args):
        print(f"{self.address_string()} - {format % args}")


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), RequestHandler)
    print(f"{APP_NAME} {VERSION} listening on http://{HOST}:{PORT}")
    server.serve_forever()
