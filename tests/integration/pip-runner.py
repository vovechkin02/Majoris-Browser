"""Native X11 PiP surface/identity/lifecycle test on a disposable Xvfb display."""
import ctypes,ctypes.util,functools,hashlib,http.server,json,os,pathlib,subprocess,sys,tempfile,threading,time
P=ctypes.c_void_p;U=ctypes.c_ulong;I=ctypes.c_int
class Hint(ctypes.Structure):_fields_=[('name',P),('kind',P)]
class Attributes(ctypes.Structure):
    _fields_=[('x',I),('y',I),('width',I),('height',I),('border',I),('depth',I),('visual',P),('root',U),('klass',I),('bit_gravity',I),('win_gravity',I),('backing_store',I),('backing_planes',U),('backing_pixel',U),('save_under',I),('colormap',U),('map_installed',I),('map_state',I),('all_event_masks',ctypes.c_long),('your_event_mask',ctypes.c_long),('do_not_propagate_mask',ctypes.c_long),('override_redirect',I),('screen',P)]
class Image(ctypes.Structure):
    _fields_=[('width',I),('height',I),('xoffset',I),('format',I),('data',P),('byte_order',I),('bitmap_unit',I),('bitmap_bit_order',I),('bitmap_pad',I),('depth',I),('bytes_per_line',I),('bits_per_pixel',I)]
class Message(ctypes.Structure):
    _fields_=[('type',I),('serial',U),('send_event',I),('display',P),('window',U),('message_type',U),('format',I),('data',ctypes.c_long*5)]
class Event(ctypes.Union):_fields_=[('message',Message),('pad',ctypes.c_long*24)]
lib=ctypes.CDLL(ctypes.util.find_library('X11'))
lib.XOpenDisplay.argtypes=[ctypes.c_char_p];lib.XOpenDisplay.restype=P
lib.XDefaultRootWindow.argtypes=[P];lib.XDefaultRootWindow.restype=U
lib.XQueryTree.argtypes=[P,U,ctypes.POINTER(U),ctypes.POINTER(U),ctypes.POINTER(ctypes.POINTER(U)),ctypes.POINTER(ctypes.c_uint)]
lib.XGetClassHint.argtypes=[P,U,ctypes.POINTER(Hint)]
lib.XFetchName.argtypes=[P,U,ctypes.POINTER(P)]
lib.XGetWindowAttributes.argtypes=[P,U,ctypes.POINTER(Attributes)]
lib.XMoveResizeWindow.argtypes=[P,U,I,I,ctypes.c_uint,ctypes.c_uint]
lib.XGetImage.argtypes=[P,U,I,I,ctypes.c_uint,ctypes.c_uint,U,I];lib.XGetImage.restype=ctypes.POINTER(Image)
lib.XDestroyImage.argtypes=[ctypes.POINTER(Image)]
lib.XInternAtom.argtypes=[P,ctypes.c_char_p,I];lib.XInternAtom.restype=U
lib.XSendEvent.argtypes=[P,U,I,ctypes.c_long,ctypes.POINTER(Event)]
lib.XFree.argtypes=[P];lib.XSync.argtypes=[P,I];lib.XCloseDisplay.argtypes=[P]
Error=ctypes.CFUNCTYPE(I,P,P)
ignore_error=Error(lambda display,event:0);lib.XSetErrorHandler.argtypes=[Error];lib.XSetErrorHandler(ignore_error)
display=lib.XOpenDisplay(None);assert display
def windows(identity):
    root,parent=U(),U();count=ctypes.c_uint();children=ctypes.POINTER(U)();result=[]
    if lib.XQueryTree(display,lib.XDefaultRootWindow(display),ctypes.byref(root),ctypes.byref(parent),ctypes.byref(children),ctypes.byref(count)):
        for window in children[:count.value]:
            hint=Hint();name=P();attr=Attributes();classes=[];title=''
            if lib.XGetClassHint(display,window,ctypes.byref(hint)):
                for value in (hint.name,hint.kind):
                    if value:classes.append(ctypes.string_at(value).decode());lib.XFree(value)
            if lib.XFetchName(display,window,ctypes.byref(name)) and name.value:title=ctypes.string_at(name.value).decode(errors='replace');lib.XFree(name)
            if lib.XGetWindowAttributes(display,window,ctypes.byref(attr)) and attr.map_state==2 and title!='Majoris PiP fixture' and classes==[identity,identity]:result.append((window,attr))
        if children:lib.XFree(children)
    return result
def pixels(window,attr):
    image=lib.XGetImage(display,window,attr.width//2-50,attr.height//2-30,100,60,U(-1).value,2)
    assert image,'PiP native surface has no readable pixels'
    try:
        assert 0<image.contents.bytes_per_line<=4096
        return hashlib.sha256(ctypes.string_at(image.contents.data,image.contents.bytes_per_line*60)).hexdigest()
    finally:lib.XDestroyImage(image)
def close(window):
    event=Event();event.message.type=33;event.message.send_event=1;event.message.display=display;event.message.window=window;event.message.message_type=lib.XInternAtom(display,b'WM_PROTOCOLS',0);event.message.format=32;event.message.data[0]=lib.XInternAtom(display,b'WM_DELETE_WINDOW',0)
    assert lib.XSendEvent(display,window,0,0,ctypes.byref(event));lib.XSync(display,0)
binary,helper,resources,fixtures=sys.argv[1:]
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(http.server.SimpleHTTPRequestHandler,directory=fixtures));threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    for mode in ('browser','app','private'):
        identity='com.majoris.browser.WebApp.testfixture' if mode=='app' else 'com.majoris.browser'
        with tempfile.TemporaryDirectory(prefix='majoris-pip-'+mode+'-') as folder:
            root=pathlib.Path(folder);env=dict(os.environ,CHROME_DESKTOP=identity+'.desktop',GDK_BACKEND='x11',GSK_RENDERER='cairo',MAJORIS_CEF_TEST_BASIC_STORE='1');env.pop('MAJORIS_CEF_TEST_HEADLESS',None)
            process=subprocess.Popen([binary,helper,resources,folder,f'http://127.0.0.1:{server.server_port}/pip.html',mode],env=env)
            checked=False;navigated=False;crashed=False;deadline=time.monotonic()+55
            try:
                while process.poll() is None and time.monotonic()<deadline:
                    if (root/'pip-open').exists() and not checked:
                        found=windows(identity)
                        if len(found)!=1:time.sleep(.1);continue
                        window,attr=found[0];first=pixels(window,attr);time.sleep(.5);second=pixels(window,attr);assert first!=second,'Native PiP video surface does not advance'
                        lib.XMoveResizeWindow(display,window,80,90,480,270);lib.XSync(display,0);time.sleep(.3)
                        resized=windows(identity);assert len(resized)==1;attr=resized[0][1];assert (attr.x,attr.y,attr.width,attr.height)==(80,90,480,270),(attr.x,attr.y,attr.width,attr.height)
                        close(window);checked=True
                    if (root/'navigating').exists() and not navigated and not windows(identity):(root/'navigation-verified').write_text('1');navigated=True
                    if (root/'crashed').exists() and not crashed and not windows(identity):(root/'crash-verified').write_text('1');crashed=True
                    time.sleep(.05)
                assert process.wait(timeout=2)==0
                if (root/'unsupported').exists():assert not checked;print(mode+': standard SDK correctly refuses native OSR PiP',flush=True)
                else:assert checked and navigated and crashed and (root/'source-closing').exists();print(json.dumps({'mode':mode,'wm_class':identity,'native_video_advances':True,'native_resize_and_close':True,'navigation_and_crash_cleanup':True}),flush=True)
                limit=time.monotonic()+3
                while windows(identity) and time.monotonic()<limit:time.sleep(.1)
                assert not windows(identity),'PiP surface survived source/application destruction'
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:process.wait(timeout=3)
                    except subprocess.TimeoutExpired:process.kill();process.wait()
finally:server.shutdown();server.server_close();lib.XCloseDisplay(display)
