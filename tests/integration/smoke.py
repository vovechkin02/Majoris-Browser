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
import time

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
               MAJORIS_UI_SMOKE='1', MAJORIS_CEF_TEST_HEADLESS='1', MAJORIS_CEF_TEST_BASIC_STORE='1', MAJORIS_UI_FIXTURE=url)
    browser=subprocess.Popen([str(binary)],env=env)
    installed=None
    deadline=time.monotonic()+20
    database=root/'data/majoris-browser/browser/browser.db'
    while time.monotonic()<deadline and browser.poll() is None:
        if database.exists():
            try:
                with sqlite3.connect(database) as db:
                    installed=db.execute('SELECT id,metadata FROM webapps').fetchone()
                if installed and (root/f'data/applications/com.majoris.browser.WebApp.{installed[0]}.desktop').exists():
                    break
            except sqlite3.Error:
                pass
        time.sleep(0.1)
    assert installed, 'Browser did not publish the installed application'
    app_env=dict(env,MAJORIS_APP_SMOKE_LIFETIME='12')
    application=subprocess.Popen([str(binary),'--app='+installed[0]],env=app_env)
    assert browser.wait(timeout=30)==0
    assert application.poll() is None, 'Installed app exited with Browser'
    assert application.wait(timeout=20)==0
    with sqlite3.connect(root / 'data/majoris-browser/browser/browser.db') as db:
        app_id, serialized = db.execute('SELECT id,metadata FROM webapps').fetchone()
    metadata=json.loads(serialized)
    assert metadata['name']=='Fixture App'
    assert metadata['start_url']==url
    assert metadata['manifest_url'].endswith('/app.webmanifest')
    icon=pathlib.Path(metadata['icon_path'])
    assert icon.is_file() and icon.suffix=='.png'
    assert icon.read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
    assert metadata['theme_color']=='#304d80'
    assert (root / f'data/applications/com.majoris.browser.WebApp.{app_id}.desktop').is_file()
    with sqlite3.connect(database) as db:
        state,clean=db.execute('SELECT state,clean FROM browser_snapshot').fetchone()
    restored=json.loads(state)
    assert clean==1 and len(restored)==2
    assert sorted(len(window['tabs']) for window in restored)==[1,2]
    assert 'private-window' not in state
    assert 'second-window' in state
    with sqlite3.connect(database) as db:
        assert db.execute("SELECT count(*) FROM history WHERE url LIKE '%private-window%'").fetchone()[0]==0
    server.shutdown()
