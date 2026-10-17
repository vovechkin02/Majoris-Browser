"""Probe genuine Chromium notification display and activation via desktop D-Bus."""
import functools
import http.server
import os
import pathlib
import subprocess
import sys
import tempfile
import threading
from gi.repository import Gio,GLib

xml='''<node><interface name="org.freedesktop.Notifications">
<method name="GetCapabilities"><arg direction="out" type="as"/></method>
<method name="GetServerInformation"><arg direction="out" type="s"/><arg direction="out" type="s"/><arg direction="out" type="s"/><arg direction="out" type="s"/></method>
<method name="Notify"><arg direction="in" type="s"/><arg direction="in" type="u"/><arg direction="in" type="s"/><arg direction="in" type="s"/><arg direction="in" type="s"/><arg direction="in" type="as"/><arg direction="in" type="a{sv}"/><arg direction="in" type="i"/><arg direction="out" type="u"/></method>
<method name="CloseNotification"><arg direction="in" type="u"/></method>
<signal name="ActionInvoked"><arg type="u"/><arg type="s"/></signal><signal name="NotificationClosed"><arg type="u"/><arg type="u"/></signal>
</interface></node>'''
connection=Gio.bus_get_sync(Gio.BusType.SESSION,None)
connection.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',('org.freedesktop.Notifications',0)),None,0,-1,None)
received=[]
closed=[]
def method(conn,sender,path,interface,name,parameters,invocation):
    if name=='GetCapabilities': invocation.return_value(GLib.Variant('(as)',(['body','actions'],)))
    elif name=='GetServerInformation': invocation.return_value(GLib.Variant('(ssss)',('Majoris test desktop','Majoris','1','1.2')))
    elif name=='Notify':
        values=parameters.unpack();received.append(values)
        invocation.return_value(GLib.Variant('(u)',(1,)))
        def click():
            connection.emit_signal(None,'/org/freedesktop/Notifications','org.freedesktop.Notifications','ActionInvoked',GLib.Variant('(us)',(1,'default')))
            return False
        GLib.timeout_add(300,click)
    else:
        closed.append(parameters.unpack()[0]);invocation.return_value(None)
        connection.emit_signal(None,'/org/freedesktop/Notifications','org.freedesktop.Notifications','NotificationClosed',GLib.Variant('(uu)',(1,3)))
connection.register_object('/org/freedesktop/Notifications',Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0],method,None,None)
binary,helper,resources,fixtures=(str(pathlib.Path(value).resolve()) for value in sys.argv[1:])
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(http.server.SimpleHTTPRequestHandler,directory=fixtures))
threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory(prefix='majoris-notification-probe-') as root:
    data=pathlib.Path(root)/'data';desktop=data/'applications/com.majoris.browser.WebApp.a11111111111111111111111111111111.desktop';desktop.parent.mkdir(parents=True)
    desktop.write_text('[Desktop Entry]\nType=Application\nName=Majoris Fixture App\nExec=true\nIcon='+str(pathlib.Path(fixtures)/'app-icon.svg')+'\n')
    env=dict(os.environ,XDG_DATA_HOME=str(data),XDG_CONFIG_HOME=str(pathlib.Path(root)/'config'),XDG_CACHE_HOME=str(pathlib.Path(root)/'cache'),MAJORIS_CEF_TEST_BASIC_STORE='1',MAJORIS_CEF_DISPLAY_NAME='Majoris Fixture App',CHROME_DESKTOP=desktop.name)
    env.pop('MAJORIS_CEF_TEST_HEADLESS',None)
    process=subprocess.Popen([binary,helper,resources,root,f'http://127.0.0.1:{server.server_port}/notifications.html'],env=env)
    loop=GLib.MainLoop()
    def poll():
        if process.poll() is None:return True
        loop.quit();return False
    GLib.timeout_add(100,poll);loop.run()
    print('Desktop Notify calls:',len(received))
    for values in received: print('Attribution:',values[0],'Icon:',values[2],'Summary:',values[3],'Body:',values[4],'Hints:',values[6])
    print('Desktop CloseNotification calls:',len(closed))
    result=process.returncode
    if result==0:
        assert len(received)==1
        assert closed==[1]
        assert received[0][0]=='Majoris Fixture App'
        assert received[0][3]=='Majoris fixture notification'
        assert 'Real Chromium notification body' in received[0][4]
        assert received[0][6]['desktop-entry']=='com.majoris.browser.WebApp.a11111111111111111111111111111111'
server.shutdown()
raise SystemExit(result)
