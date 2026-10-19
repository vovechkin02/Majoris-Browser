namespace MajorisBrowser {
    public abstract class BrowserSurface : Gtk.Widget {
        public MajorisCef.View engine { get; protected set; }
        public string url = "about:blank";
        public string page_title = "New Tab";
        public bool has_frame;
        public bool loading;
        public bool can_go_back;
        public bool can_go_forward;
        public string navigation_state="";
        public string navigation_state_url="";
        public string security=_("Connection information is not available yet");
        public string certificate_info="{}";
        public Bytes? favicon;
        public TabAudioState audio_state=new TabAudioState();
        public signal void changed (string kind, string value);
        public bool closed { get; protected set; }
        private bool close_pending;
        public void close () { if(closed)return;closed=true;engine.close (); }
        public async bool request_close () {
            if(closed)return true;
            if(close_pending)return false;
            close_pending=true;bool accepted=false,resolved=false;
            ulong handler=engine.event.connect((kind,value)=>{
                if(!resolved && (kind=="closed" || kind=="close-cancelled")){
                    resolved=true;
                    accepted=kind=="closed";
                    Idle.add(()=>{request_close.callback();return Source.REMOVE;});
                }
            });
            engine.request_close();yield;
            engine.disconnect(handler);close_pending=false;
            if(accepted)closed=true;
            return accepted;
        }
        public void navigate (string target) { engine.load (target); }
    }
    public class OffscreenBrowserSurface : BrowserSurface {
        private Gdk.Texture? texture;
        private Gtk.IMMulticontext im;
        private WebAccessibleHost accessibility;
        private ulong frame_handler;
        private ulong event_handler;
        private double pointer_x;
        private double pointer_y;
        private Gtk.Box error_box=new Gtk.Box(Gtk.Orientation.VERTICAL,12);
        private Gtk.Label error_message=new Gtk.Label("");
        public OffscreenBrowserSurface (string profile, bool ephemeral, string target, string scope = "",string permissions="[]",bool threat_checks=false,string history="") {
            this.with_engine(new MajorisCef.View.with_session(profile,ephemeral,target,scope,permissions,threat_checks,ephemeral?"":history));
        }
        public OffscreenBrowserSurface.with_engine(MajorisCef.View supplied) {
            WebDrag.attach(this);
            hexpand = true; vexpand = true; focusable = true;
            error_box.set_parent(this);error_box.halign=Gtk.Align.CENTER;error_box.valign=Gtk.Align.CENTER;error_box.visible=false;error_message.wrap=true;error_box.append(error_message);
            var retry=new Gtk.Button.with_label(_("Reload Page"));error_box.append(retry);retry.clicked.connect(()=>{error_box.visible=false;engine.command("reload");});
            engine = supplied;
            accessibility=new WebAccessibleHost(this);accessibility.set_parent(this);
            map.connect(()=>engine.set_accessibility(get_at_context()!=null));
            WebDrop.attach(this);
            frame_handler=engine.frame.connect ((bytes,w,h) => {
                if(closed)return;
                has_frame=true;
                texture = new Gdk.MemoryTexture (w,h,Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED,bytes,w*4);
                queue_draw ();
            });
            event_handler=engine.event.connect ((kind,value) => {
                if(kind=="closed"){closed=true;accessibility.clear();engine.disconnect(frame_handler);engine.disconnect(event_handler);frame_handler=0;event_handler=0;changed(kind,value);return;}
                if(closed)return;
                if(kind=="accessibility-tree"){accessibility.consume(value);return;}
                if(kind=="accessibility-location"){accessibility.consume_locations(value);return;}
                if(kind=="navigation-started" || kind=="crashed")accessibility.clear();
                if(kind=="history"){
                    navigation_state="";navigation_state_url="";
                    if(value!="" && value.length<=4*1024*1024)try{var parser=new Json.Parser();parser.load_from_data(value);navigation_state_url=parser.get_root().get_object().get_string_member("selected_url");navigation_state=value;}catch(Error e){warning("Invalid native session state");}
                }
                audio_state.update(kind,value);

                if (kind == "url") {url = value;security=_("Connection information is not available yet");certificate_info="{}";}
                if(kind=="certificate")certificate_info=value;
                if(kind=="security")security=value;
                if(kind=="focus-request"){var window=get_root() as Gtk.Window;if(window!=null){window.present();grab_focus();}}
                if(kind=="focus-escape"){var root=get_root() as Gtk.Widget;if(root!=null)root.child_focus(value=="1"?Gtk.DirectionType.TAB_FORWARD:Gtk.DirectionType.TAB_BACKWARD);}
                if(kind=="image:favicon" && value!="")favicon=new Bytes(Base64.decode(value));
                if(kind=="ime-caret"){var fields=value.split(",");if(fields.length==4){Gdk.Rectangle rect={int.parse(fields[0]),int.parse(fields[1]),int.parse(fields[2]),int.parse(fields[3])};im.set_cursor_location(rect);}}
                if (kind == "title") page_title = value;
                if(kind=="error" || kind=="crashed"){error_message.label=kind=="crashed"?_("This page stopped responding. Reload to continue."):_("This page could not be loaded.")+"\n"+value;error_box.visible=true;queue_allocate();}
                if(kind=="loading" && value=="1")error_box.visible=false;
                if(kind=="loading")loading=value=="1";
                if(kind=="back")can_go_back=value=="1";
                if(kind=="forward")can_go_forward=value=="1";
                if (kind == "tooltip") tooltip_text = value;
                if (kind == "cursor") set_cursor_from_name (value);
                if (kind == "ready") engine.resize (get_width (),get_height (),get_scale_factor ());
                changed (kind,value);
            });
            im = new Gtk.IMMulticontext (); im.set_client_widget (this);
            im.commit.connect ((text) => engine.ime (text,0,true));
            im.preedit_changed.connect (() => {
                string text;Pango.AttrList attrs;int cursor;im.get_preedit_string(out text,out attrs,out cursor);
                // CEF positions are UTF-16 code units; GTK supplies Unicode characters.
                string prefix=text.substring(0,text.index_of_nth_char(cursor));
                int units=0;for(int i=0;i<prefix.char_count();i++)units+=prefix.get_char(prefix.index_of_nth_char(i))>0xffff?2:1;
                engine.ime(text,units,false);
            });
            var focus = new Gtk.EventControllerFocus ();
            focus.enter.connect (() => { engine.focus (true); im.focus_in (); });
            focus.leave.connect (() => { engine.focus (false); im.focus_out ();im.reset();engine.ime("",0,false); }); add_controller (focus);
            var motion = new Gtk.EventControllerMotion ();
            motion.motion.connect ((x,y) => { pointer_x=x; pointer_y=y; engine.pointer (0,(int)x,(int)y,0,modifiers (motion.get_current_event_state ()),0,0); }); motion.leave.connect(()=>engine.pointer(4,(int)pointer_x,(int)pointer_y,0,0,0,0));add_controller (motion);
            var click = new Gtk.GestureClick (); click.button = 0;
            click.pressed.connect ((n,x,y) => { grab_focus (); engine.pointer (1,(int)x,(int)y,(int)click.get_current_button (),modifiers (click.get_current_event_state ()),0,0); });
            click.released.connect ((n,x,y) => engine.pointer (2,(int)x,(int)y,(int)click.get_current_button (),modifiers (click.get_current_event_state ()),0,0)); add_controller (click);
            var scroll = new Gtk.EventControllerScroll (Gtk.EventControllerScrollFlags.BOTH_AXES);
            scroll.scroll.connect ((dx,dy) => { engine.pointer (3,(int)pointer_x,(int)pointer_y,0,modifiers (scroll.get_current_event_state ()),(int)(-dx*80),(int)(-dy*80)); return true; }); add_controller (scroll);
            var keys = new Gtk.EventControllerKey (); keys.set_im_context (im);
            keys.key_pressed.connect ((key,code,state) => {
                var window=get_root() as Gtk.Window;
                if(window!=null && window.application!=null){
                    string accelerator=Gtk.accelerator_name(key,state & Gtk.accelerator_get_default_mod_mask());
                    foreach(string action in window.application.get_actions_for_accel(accelerator))if(window.activate_action(action,null))return true;
                }
                engine.key (0,windows_key (key),(int)code,modifiers (state));
                if(key==Gdk.Key.Return && (state & (Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.ALT_MASK))==0)engine.text("\r");
                return true;
            });
            keys.key_released.connect ((key,code,state) => engine.key (1,windows_key (key),(int)code,modifiers (state))); add_controller (keys);
        }
        private static int windows_key (uint key) {
            switch (key) {
                case Gdk.Key.BackSpace: return 8; case Gdk.Key.Tab: return 9; case Gdk.Key.Return: return 13;
                case Gdk.Key.Escape: return 27; case Gdk.Key.Delete: return 46;
                case Gdk.Key.Left: return 37; case Gdk.Key.Up: return 38; case Gdk.Key.Right: return 39; case Gdk.Key.Down: return 40;
                case Gdk.Key.Home: return 36; case Gdk.Key.End: return 35; case Gdk.Key.Page_Up: return 33; case Gdk.Key.Page_Down: return 34;
                default: return (int)Gdk.keyval_to_upper (key);
            }
        }
        private static int modifiers (Gdk.ModifierType m) {
            int result=0;
            if ((m & Gdk.ModifierType.SHIFT_MASK) != 0) result |= 2;
            if ((m & Gdk.ModifierType.CONTROL_MASK) != 0) result |= 4;
            if ((m & Gdk.ModifierType.ALT_MASK) != 0) result |= 8;
            if ((m & Gdk.ModifierType.BUTTON1_MASK) != 0) result |= 16;
            if ((m & Gdk.ModifierType.BUTTON2_MASK) != 0) result |= 32;
            if ((m & Gdk.ModifierType.BUTTON3_MASK) != 0) result |= 64;
            return result;
        }
        public override void size_allocate (int width,int height,int baseline) {
            double scale=get_scale_factor();var native=get_native();if(native!=null && native.get_surface()!=null)scale=native.get_surface().get_scale();
            engine.resize (width,height,scale);
            accessibility.allocate(width,height,baseline,null);
            if(error_box.visible)error_box.allocate(width,height,baseline,null);
        }
        public override void snapshot (Gtk.Snapshot snapshot) {
            if(error_box.visible){snapshot_child(error_box,snapshot);return;}
            if (texture != null) {
                Graphene.Rect rect = Graphene.Rect (); rect.init (0,0,get_width (),get_height ());
                snapshot.append_texture (texture,rect);
            }
        }
        protected override void dispose(){accessibility.clear();if(accessibility.get_parent()!=null)accessibility.unparent();if(error_box.get_parent()!=null)error_box.unparent();base.dispose();}
    }
}
