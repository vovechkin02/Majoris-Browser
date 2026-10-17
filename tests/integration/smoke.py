#!/usr/bin/env python3
"""Exercise real GTK windows and CEF under a disposable XDG home."""
import functools
import http.server
import json
import os
import pathlib
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import threading

binary, helper, runtime, source = map(pathlib.Path, sys.argv[1:])
with tempfile.TemporaryDirectory(prefix='majoris-ui-') as temp:
    root = pathlib.Path(temp)
    schema = root / 'schemas'
    schema.mkdir()
    shutil.copy(source / 'data/com.majoris.browser.gschema.xml', schema)
    subprocess.run(['glib-compile-schemas', str(schema)], check=True)
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(source / 'tests/fixtures'))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f'http://127.0.0.1:{server.server_port}/platform.html'
    env = dict(os.environ, XDG_DATA_HOME=str(root / 'data'), XDG_CONFIG_HOME=str(root / 'config'),
               XDG_CACHE_HOME=str(root / 'cache'), GSETTINGS_SCHEMA_DIR=str(schema),
               GSETTINGS_BACKEND='memory', GSK_RENDERER='cairo', G_DEBUG='fatal-criticals',
               MAJORIS_CEF_HELPER=str(helper), MAJORIS_CEF_RESOURCES=str(runtime),
               MAJORIS_UI_SMOKE='1', MAJORIS_CEF_TEST_HEADLESS='1', MAJORIS_UI_FIXTURE=url)
    subprocess.run([str(binary)], env=env, check=True, timeout=30)
    with sqlite3.connect(root / 'data/majoris-browser/browser/browser.db') as db:
        app_id, serialized = db.execute('SELECT id,metadata FROM webapps').fetchone()
    metadata=json.loads(serialized)
    assert metadata['name']=='Fixture App'
    assert metadata['start_url']==url
    assert metadata['manifest_url'].endswith('/app.webmanifest')
    assert (root / f'data/applications/com.majoris.browser.WebApp.{app_id}.desktop').is_file()
    subprocess.run([str(binary), '--app=' + app_id], env=env, check=True, timeout=30)
    server.shutdown()
