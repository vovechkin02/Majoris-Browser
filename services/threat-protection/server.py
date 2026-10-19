#!/usr/bin/env python3
"""Optional operator backend. Loopback only; deploy behind a TLS reverse proxy.

Never installed or launched by the Browser. No destination URL is fetched.
"""
import argparse
import collections
import datetime
import hashlib
import hmac
import http.server
import json
import pathlib
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

TYPES = {'MALWARE', 'SOCIAL_ENGINEERING', 'UNWANTED_SOFTWARE'}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class Service:
    def __init__(self, config):
        if config.get('provider_use_authorised') is not True:
            raise ValueError('Operator must establish and explicitly acknowledge provider authorisation')
        self.tokens = config['client_token_sha256']
        if not 1 <= len(self.tokens) <= 10000 or any(
                len(t) != 64 or any(c not in '0123456789abcdef' for c in t) for t in self.tokens):
            raise ValueError('Supply bounded SHA-256 hashes of random per-installation tokens')
        self.key = pathlib.Path(config['provider_key_file']).read_text().strip()
        if not self.key or len(self.key) > 512 or any(c in self.key for c in '\r\n'):
            raise ValueError('Invalid provider key')
        self.limit = int(config.get('requests_per_minute', 30))
        self.global_limit = int(config.get('global_requests_per_minute', 600))
        if not 1 <= self.limit <= 600 or not 1 <= self.global_limit <= 100000:
            raise ValueError('Invalid quota')
        self.lock = threading.Lock()
        self.usage = collections.defaultdict(collections.deque)
        self.capacity = threading.BoundedSemaphore(8)
        self.last_success = 0.0
        self.backoff = 0.0

    def authenticate(self, header):
        if not header.startswith('Bearer ') or len(header) > 520:
            return None
        token = header[7:]
        if len(token) < 32:
            return None
        digest = hashlib.sha256(token.encode()).hexdigest()
        # Evaluate all comparisons; do not disclose which rotation key matched.
        valid = sum(hmac.compare_digest(digest, allowed) for allowed in self.tokens)
        return digest if valid else None

    def reserve(self, identity):
        with self.lock:
            now = time.monotonic()
            if now < self.backoff:
                return False
            for key, limit in ((identity, self.limit), ('global', self.global_limit)):
                queue = self.usage[key]
                while queue and queue[0] <= now - 60:
                    queue.popleft()
                if len(queue) >= limit:
                    return False
            self.usage[identity].append(now)
            self.usage['global'].append(now)
            return True

    def provider(self, target):
        query = urllib.parse.urlencode([('threatTypes', t) for t in sorted(TYPES)] + [('uri', target)])
        request = urllib.request.Request('https://webrisk.googleapis.com/v1/uris:search?' + query,
                                         headers={'X-Goog-Api-Key': self.key})
        with urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect).open(request, timeout=2) as response:
            body = response.read(65537)
            if len(body) > 65536:
                raise ValueError('Provider response too large')
            return json.loads(body)

    @staticmethod
    def normalize(data):
        if data == {}:
            return {}
        threat = data['threat']
        categories = threat['threatTypes']
        if not isinstance(categories, list) or not categories or any(t not in TYPES for t in categories):
            raise ValueError('Invalid threat categories')
        expiry = threat['expireTime']
        when = datetime.datetime.fromisoformat(expiry.replace('Z', '+00:00'))
        if when.tzinfo is None:
            raise ValueError('Expiry requires a timezone')
        return {'threat': {'threatTypes': sorted(set(categories)), 'expireTime': expiry}}

    def lookup(self, target):
        if not self.capacity.acquire(blocking=False):
            return 503, {'error': 'temporarily_unavailable'}
        try:
            answer = self.normalize(self.provider(target))
            self.last_success = time.monotonic()
            return 200, answer
        except urllib.error.HTTPError as error:
            self.last_success = 0.0
            if error.code in (429, 503):
                with self.lock:
                    try: delay = max(60, min(600, int(error.headers.get('Retry-After', '60'))))
                    except (ValueError, TypeError): delay = 60
                    self.backoff = time.monotonic() + delay
            return 503, {'error': 'provider_unavailable'}
        except Exception:
            self.last_success = 0.0
            # Never include exception text: upstream failures can contain URLs.
            return 503, {'error': 'provider_unavailable'}
        finally:
            self.capacity.release()


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = 'MajorisThreatService/1'

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, *args):
        pass  # No URL, authorization or destination logging.

    def send(self, status, data):
        body = json.dumps(data, separators=(',', ':')).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        if status in (429, 503): self.send_header('Retry-After', '60')
        self.end_headers()
        try: self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError): pass

    def do_GET(self):
        service = self.server.service
        identity = service.authenticate(self.headers.get('Authorization', ''))
        if not identity:
            return self.send(401, {'error': 'unauthorised'})
        if len(self.path) > 32768 or self.headers.get('Transfer-Encoding') or self.headers.get('Content-Length', '0') != '0':
            return self.send(400, {'error': 'invalid_request'})
        if not service.reserve(identity):
            return self.send(429, {'error': 'rate_limited'})
        try:
            parsed = urllib.parse.urlsplit(self.path)
            if parsed.path == '/health' and not parsed.query and not parsed.scheme and not parsed.netloc and not parsed.fragment:
                healthy = service.last_success > 0 and time.monotonic() - service.last_success < 60
                return self.send(200 if healthy else 503, {'provider_recently_verified': healthy})
            if parsed.path != '/v1/uris:search' or parsed.scheme or parsed.netloc or parsed.fragment:
                raise ValueError()
            query = urllib.parse.parse_qs(parsed.query, strict_parsing=True, max_num_fields=4)
            if set(query) != {'uri', 'threatTypes'} or len(query['uri']) != 1 or set(query['threatTypes']) != TYPES or len(query['threatTypes']) != 3:
                raise ValueError()
            target = query['uri'][0]
            url = urllib.parse.urlsplit(target)
            if len(target.encode()) > 8192 or url.scheme not in ('http', 'https') or not url.hostname or url.username is not None or url.password is not None or url.fragment or any(ord(c) < 32 for c in target):
                raise ValueError()
        except (ValueError, KeyError):
            return self.send(400, {'error': 'invalid_request'})
        status, answer = service.lookup(target)
        self.send(status, answer)


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    def handle_error(self, request, client_address):
        # Default socketserver tracebacks can disclose request/provider data.
        # The authenticated health endpoint reports operational availability.
        pass
    # Worker population is bounded by reverse-proxy concurrency and connections;
    # provider work has its own explicit semaphore and short deadlines.
    def __init__(self, address, service):
        super().__init__(address, Handler)
        self.service = service
        self.connections = threading.BoundedSemaphore(32)

    def process_request(self, request, address):
        if not self.connections.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try: super().process_request(request, address)
        except Exception:
            self.connections.release()
            raise

    def process_request_thread(self, request, address):
        try: super().process_request_thread(request, address)
        finally: self.connections.release()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=pathlib.Path, required=True)
    parser.add_argument('--port', type=int, default=8787)
    args = parser.parse_args()
    service = Service(json.loads(args.config.read_text()))
    Server(('127.0.0.1', args.port), service).serve_forever()


if __name__ == '__main__': main()
