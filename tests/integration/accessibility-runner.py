import functools,http.server,os,pathlib,subprocess,sys,tempfile,threading,time
import gi
gi.require_version('Atspi','2.0')
from gi.repository import Atspi,GLib
binary,helper,resources,fixtures=sys.argv[1:]
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(http.server.SimpleHTTPRequestHandler,directory=fixtures))
threading.Thread(target=server.serve_forever,daemon=True).start()
def walk(node,depth=0):
    if depth>60:return
    yield node
    for index in range(node.get_child_count()):
        child=node.get_child_at_index(index)
        if child:yield from walk(child,depth+1)
with tempfile.TemporaryDirectory(prefix='majoris-atspi-') as root:
    environment=dict(os.environ,GDK_BACKEND='x11',GTK_A11Y='atspi',MAJORIS_CEF_TEST_BASIC_STORE='1')
    proc=subprocess.Popen([binary,helper,resources,root,f'http://127.0.0.1:{server.server_port}/accessibility.html'],env=environment)
    try:
        deadline=time.monotonic()+25
        while time.monotonic()<deadline:
            while GLib.MainContext.default().pending():GLib.MainContext.default().iteration(False)
            assert proc.poll() is None,'Fixture exited before accessibility verification'
            nodes=list(walk(Atspi.get_desktop(0)))
            names=[n.get_name() for n in nodes]
            if 'Fixture name' in names and 'Activate fixture' in names and 'Frame action' in names and 'Foreign frame action' in names:
                field=next(n for n in nodes if n.get_name()=='Fixture name')
                text=field.get_text_iface()
                assert text is not None; actual=Atspi.Text.get_text(text,0,-1); assert actual=='Sample text',repr(actual)
                check=next(n for n in nodes if n.get_name()=='Fixture checkbox' and n.get_role()==Atspi.Role.CHECK_BOX)
                assert check.get_state_set().contains(Atspi.StateType.CHECKED)
                assert 'Readable document text.' in names
                bounds=Atspi.Component.get_extents(field,Atspi.CoordType.WINDOW);assert bounds.width>100 and bounds.height>10
                deadline=time.monotonic()+10
                while time.monotonic()<deadline:
                    if Atspi.Text.get_text(text,0,-1)=='Updated text' and Atspi.Text.get_caret_offset(text)==7 and field.get_state_set().contains(Atspi.StateType.FOCUSED) and Atspi.Text.get_n_selections(text)==1:break
                    time.sleep(.2)
                else:raise AssertionError('Changed text, caret and focus did not reach AT-SPI')
                assert Atspi.Text.get_n_selections(text)==1
                moved=Atspi.Component.get_extents(field,Atspi.CoordType.WINDOW);assert moved.x>bounds.x+30
                assert 'Fixture activated' in [n.get_name() for n in walk(Atspi.get_desktop(0))]
                print('AT-SPI traverses Chromium document, roles, checked state, live changes, text, caret, selection and focus: PASS')
                break
            time.sleep(.2)
        else:raise AssertionError('Web content absent from AT-SPI: '+repr(names))
    finally:
        proc.terminate()
        try:proc.wait(timeout=5)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()
server.shutdown()
