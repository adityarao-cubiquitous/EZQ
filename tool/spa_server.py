from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import os


class SpaHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) and not Path(self.path).suffix:
            self.path = "/index.html"
        return super().send_head()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8085)
    parser.add_argument("--directory", default="build/web")
    args = parser.parse_args()

    handler = lambda *handler_args, **handler_kwargs: SpaHandler(
        *handler_args,
        directory=args.directory,
        **handler_kwargs,
    )
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Serving {args.directory} at http://127.0.0.1:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
