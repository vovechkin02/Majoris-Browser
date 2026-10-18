import ctypes
import ctypes.util
import functools
import http.server
import os
import pathlib
import struct
import subprocess
import sys
import tempfile
import threading
import time
import zlib

binary, helper, resources, fixtures = sys.argv[1:]
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B',4,4,8,2,0,0,0)) + chunk(b'IDAT',zlib.compress((b'\0'+b'\x12\x70\xc0'*4)*4)) + chunk(b'IEND',b'')
class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/drag-image.png':
            self.send_response(200); self.send_header('Content-Type','image/png'); self.send_header('Content-Length',str(len(png))); self.end_headers(); self.wfile.write(png)
        else:
            super().do_GET()
server = http.server.ThreadingHTTPServer(('127.0.0.1',0), functools.partial(Handler,directory=fixtures))
threading.Thread(target=server.serve_forever, daemon=True).start()
x = ctypes.CDLL(ctypes.util.find_library('X11'))
t = ctypes.CDLL(ctypes.util.find_library('Xtst'))
P, U, I = ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int
x.XOpenDisplay.argtypes=[ctypes.c_char_p]; x.XOpenDisplay.restype=P
x.XDefaultRootWindow.argtypes=[P]; x.XDefaultRootWindow.restype=U
x.XQueryTree.argtypes=[P,U,ctypes.POINTER(U),ctypes.POINTER(U),ctypes.POINTER(ctypes.POINTER(U)),ctypes.POINTER(ctypes.c_uint)]
x.XFetchName.argtypes=[P,U,ctypes.POINTER(P)]; x.XFree.argtypes=[P]
x.XTranslateCoordinates.argtypes=[P,U,U,I,I,ctypes.POINTER(I),ctypes.POINTER(I),ctypes.POINTER(U)]
x.XKeysymToKeycode.argtypes=[P,U]; x.XKeysymToKeycode.restype=ctypes.c_uint
x.XFlush.argtypes=[P]; x.XCloseDisplay.argtypes=[P]
t.XTestFakeMotionEvent.argtypes=[P,I,I,I,U]; t.XTestFakeButtonEvent.argtypes=[P,ctypes.c_uint,I,U]; t.XTestFakeKeyEvent.argtypes=[P,ctypes.c_uint,I,U]
display=x.XOpenDisplay(None); assert display
root_window=x.XDefaultRootWindow(display)
def window_named(parent):
    root,parent_out,n=U(),U(),ctypes.c_uint(); children=ctypes.POINTER(U)()
    if not x.XQueryTree(display,parent,ctypes.byref(root),ctypes.byref(parent_out),ctypes.byref(children),ctypes.byref(n)): return None
    ids=list(children[:n.value]); x.XFree(children)
    for window in ids:
        name=P(); x.XFetchName(display,window,ctypes.byref(name))
        text=ctypes.cast(name,ctypes.c_char_p).value if name.value else None
        if name.value: x.XFree(name)
        if text == b'Majoris real drag fixture': return window
    return None
with tempfile.TemporaryDirectory(prefix='majoris-gtk-drag-') as temp:
    path=pathlib.Path(temp); env=dict(os.environ, GDK_BACKEND='x11', G_DEBUG='fatal-criticals', GSK_RENDERER='cairo',MAJORIS_CEF_TEST_BASIC_STORE='1')
    process=subprocess.Popen([binary,helper,resources,temp,f'http://127.0.0.1:{server.server_port}/drag.html'],env=env)
    def wait_phase(expected):
        deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            if (path/'phase').exists() and (path/'phase').read_text()==expected: return
            assert process.poll() is None, f'drag fixture exited while waiting for {expected}'
            time.sleep(.05)
        raise AssertionError(f'drag fixture did not reach {expected}')
    try:
        wait_phase('ready'); window=window_named(root_window); assert window
        wx,wy,child=I(),I(),U(); assert x.XTranslateCoordinates(display,window,root_window,0,0,ctypes.byref(wx),ctypes.byref(wy),ctypes.byref(child))
        def motion(px,py):
            t.XTestFakeMotionEvent(display,-1,wx.value+px,wy.value+py,0); x.XFlush(display); time.sleep(.04)
        def button(down):
            t.XTestFakeButtonEvent(display,1,down,0); x.XFlush(display); time.sleep(.05)
        def move_drag(start,end):
            motion(*start); button(1)
            for index in range(1,16): motion(round(start[0]+(end[0]-start[0])*index/15),round(start[1]+(end[1]-start[1])*index/15))
        move_drag((50,30),(200,70)); code=x.XKeysymToKeycode(display,0xff1b); t.XTestFakeKeyEvent(display,code,1,0); t.XTestFakeKeyEvent(display,code,0,0); x.XFlush(display); button(0); wait_phase('cancelled')
        move_drag((50,30),(500,70)); button(0); wait_phase('link')
        move_drag((500,225),(200,170)); button(0); wait_phase('incoming')
        move_drag((330,40),(500,70)); button(0); wait_phase('drag-done')
        def key(symbol,down):t.XTestFakeKeyEvent(display,x.XKeysymToKeycode(display,symbol),down,0);x.XFlush(display);time.sleep(.04)
        def tap(symbol):key(symbol,1);key(symbol,0)
        def control(symbol):key(0xffe3,1);tap(symbol);key(0xffe3,0)
        motion(50,275);button(1);button(0);control(ord('v'));wait_phase('clipboard')
        control(ord('a'));control(ord('c'));motion(450,20);button(1);button(0);control(ord('v'));wait_phase('native-paste')
        motion(50,275);button(1);button(0);control(ord('a'));tap(ord('a'));tap(ord('b'));tap(ord('c'));wait_phase('typed');tap(0xff08);wait_phase('done')
        assert process.wait(timeout=15)==0
    finally:
        if process.poll() is None: process.terminate(); process.wait(timeout=10)
server.shutdown(); x.XCloseDisplay(display)
