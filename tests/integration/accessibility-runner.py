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
                multiline=next(n for n in nodes if n.get_name()=='Unicode multiline' and n.get_role()==Atspi.Role.TEXT)
                actual_multiline=Atspi.Text.get_text(multiline.get_text_iface(),0,-1)
                assert actual_multiline=='日本語😀 first\nSecond line',repr(actual_multiline)
                assert Atspi.Text.get_text(multiline.get_text_iface(),3,4)=='😀'
                editable=next(n for n in nodes if n.get_name()=='Editable fixture' and n.get_role()==Atspi.Role.TEXT)
                actual_editable=Atspi.Text.get_text(editable.get_text_iface(),0,-1)
                assert actual_editable=='Editable 日本語😀',repr(actual_editable)
                protected=next(n for n in nodes if n.get_name()=='Protected fixture' and n.get_role() in (Atspi.Role.TEXT,Atspi.Role.PASSWORD_TEXT))
                assert Atspi.Text.get_text(protected.get_text_iface(),0,-1)==''
                assert all('never-expose-this' not in name for name in names)
                bounds=Atspi.Component.get_extents(field,Atspi.CoordType.WINDOW);assert bounds.width>100 and bounds.height>10
                custom=(pathlib.Path(root)/'custom-ax').exists()
                if (pathlib.Path(root)/'custom-expected').exists() and not custom:
                    time.sleep(.05);continue
                if custom:
                    button=next(n for n in nodes if n.get_name()=='Activate fixture' and n.get_role()==Atspi.Role.PUSH_BUTTON)
                    action=button.get_action_iface();assert action is not None
                    actions=[Atspi.Action.get_action_name(action,i) for i in range(Atspi.Action.get_n_actions(action))]
                    assert 'chromium.activate' in actions,actions
                    assert Atspi.Action.do_action(action,actions.index('chromium.activate'))
                    limit=time.monotonic()+5
                    while time.monotonic()<limit:
                        if 'Fixture activated' in [n.get_name() for n in walk(Atspi.get_desktop(0))]:break
                        time.sleep(.1)
                    else:raise AssertionError('AT-SPI action did not activate the real Chromium button')
                    editing=field.get_editable_text_iface();assert editing is not None
                    replacement='AT-SPI 日本語😀'
                    assert Atspi.EditableText.set_text_contents(editing,replacement)
                    limit=time.monotonic()+5
                    while time.monotonic()<limit:
                        if Atspi.Text.get_text(text,0,-1)==replacement:break
                        time.sleep(.1)
                    else:raise AssertionError('AT-SPI editing did not update authoritative Chromium AX text')
                    selection=field.get_action_iface();assert selection is not None
                    names=[Atspi.Action.get_action_name(selection,i) for i in range(Atspi.Action.get_n_actions(selection))]
                    assert 'chromium.select-all' in names,names
                    assert Atspi.Action.do_action(selection,names.index('chromium.select-all'))
                    limit=time.monotonic()+5
                    while time.monotonic()<limit:
                        if Atspi.Text.get_n_selections(text)==1 and Atspi.Text.get_caret_offset(text)==len(replacement):break
                        time.sleep(.1)
                    else:raise AssertionError('AT-SPI selection did not reach Chromium')
                    secret_editing=protected.get_editable_text_iface();assert secret_editing is not None
                    assert not Atspi.EditableText.set_text_contents(secret_editing,'refuse-this')
                    print('Custom Chromium AT-SPI activation, Unicode editing, native selection and protected write refusal: PASS',flush=True)
                (pathlib.Path(root)/'continue').write_text('1')
                deadline=time.monotonic()+10
                while time.monotonic()<deadline:
                    if Atspi.Text.get_text(text,0,-1)=='Updated text' and Atspi.Text.get_caret_offset(text)==7 and field.get_state_set().contains(Atspi.StateType.FOCUSED) and Atspi.Text.get_n_selections(text)==1:break
                    time.sleep(.2)
                else:raise AssertionError('Changed text, caret and focus did not reach AT-SPI')
                assert Atspi.Text.get_n_selections(text)==1
                moved=Atspi.Component.get_extents(field,Atspi.CoordType.WINDOW);assert moved.x>bounds.x+30
                assert 'Timer fixture status' in [n.get_name() for n in walk(Atspi.get_desktop(0))]
                print('AT-SPI traverses Chromium document, roles, checked state, live changes, text, caret, selection and focus: PASS')
                break
            time.sleep(.2)
        else:raise AssertionError('Web content absent from AT-SPI: '+repr(names))
    finally:
        proc.terminate()
        try:proc.wait(timeout=5)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()
server.shutdown()
