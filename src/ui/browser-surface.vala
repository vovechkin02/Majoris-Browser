namespace MajorisBrowser {
    public abstract class BrowserSurface : Gtk.Widget {
        public MajorisCef.View engine { get; protected set; }
        public string url = "about:blank";
        public string page_title = "New Tab";
        public bool has_frame;
        public bool loading;
        public bool can_go_back;
        public bool can_go_forward;
        public string security=_("Connection information is not available yet");
        public Bytes? favicon;
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
        private double pointer_x;
        private double pointer_y;
        private Gtk.Box error_box=new Gtk.Box(Gtk.Orientation.VERTICAL,12);
        private Gtk.Label error_message=new Gtk.Label("");
        public OffscreenBrowserSurface (string profile, bool ephemeral, string target, string scope = "",string permissions="[]") {
            this.with_engine(new MajorisCef.View.with_permissions(profile,ephemeral,target,scope,permissions));
        }
        public OffscreenBrowserSurface.with_engine(MajorisCef.View supplied) {
            hexpand = true; vexpand = true; focusable = true;
            error_box.set_parent(this);error_box.halign=Gtk.Align.CENTER;error_box.valign=Gtk.Align.CENTER;error_box.visible=false;error_message.wrap=true;error_box.append(error_message);
            var retry=new Gtk.Button.with_label(_("Reload Page"));error_box.append(retry);retry.clicked.connect(()=>{error_box.visible=false;engine.command("reload");});
            engine = supplied;
            var text_drop=new Gtk.DropTarget(typeof(string),Gdk.DragAction.COPY);
            text_drop.on_drop.connect((value,x,y)=>{string? text=value.get_string();if(text==null || text.length>8*1024*1024 || closed)return false;engine.drop(text,"[]",(int)x,(int)y);return true;});add_controller(text_drop);
            var file_drop=new Gtk.DropTarget(typeof(Gdk.FileList),Gdk.DragAction.COPY);
            file_drop.on_drop.connect((value,x,y)=>{var files=(Gdk.FileList)value.get_boxed();if(files==null || closed)return false;var b=new Json.Builder();b.begin_array();int count=0;foreach(var file in files.get_files()){string? path=file.get_path();if(path!=null && ++count<=100)b.add_string_value(path);}b.end_array();var g=new Json.Generator();g.set_root(b.get_root());engine.drop("",g.to_data(null),(int)x,(int)y);return true;});add_controller(file_drop);
            engine.frame.connect ((bytes,w,h) => {
                has_frame=true;
                texture = new Gdk.MemoryTexture (w,h,Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED,bytes,w*4);
                queue_draw ();
            });
            engine.event.connect ((kind,value) => {
                if(closed)return;
                if(kind=="closed"){closed=true;changed(kind,value);return;}
                if (kind == "url") {url = value;security=_("Connection information is not available yet");}
                if(kind=="security")security=value;
                if(kind=="focus-request"){var window=get_root() as Gtk.Window;if(window!=null){window.present();grab_focus();}}
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
            focus.leave.connect (() => { engine.focus (false); im.focus_out (); }); add_controller (focus);
            var motion = new Gtk.EventControllerMotion ();
            motion.motion.connect ((x,y) => { pointer_x=x; pointer_y=y; engine.pointer (0,(int)x,(int)y,0,modifiers (motion.get_current_event_state ()),0,0); }); add_controller (motion);
            var click = new Gtk.GestureClick (); click.button = 0;
            click.pressed.connect ((n,x,y) => { grab_focus (); engine.pointer (1,(int)x,(int)y,(int)click.get_current_button (),modifiers (click.get_current_event_state ()),0,0); });
            click.released.connect ((n,x,y) => engine.pointer (2,(int)x,(int)y,(int)click.get_current_button (),modifiers (click.get_current_event_state ()),0,0)); add_controller (click);
            var scroll = new Gtk.EventControllerScroll (Gtk.EventControllerScrollFlags.BOTH_AXES);
            scroll.scroll.connect ((dx,dy) => { engine.pointer (3,(int)pointer_x,(int)pointer_y,0,modifiers (scroll.get_current_event_state ()),(int)(-dx*80),(int)(-dy*80)); return true; }); add_controller (scroll);
            var keys = new Gtk.EventControllerKey (); keys.set_im_context (im);
            keys.key_pressed.connect ((key,code,state) => {
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
            if(error_box.visible)error_box.allocate(width,height,baseline,null);
        }
        public override void snapshot (Gtk.Snapshot snapshot) {
            if(error_box.visible){snapshot_child(error_box,snapshot);return;}
            if (texture != null) {
                Graphene.Rect rect = Graphene.Rect (); rect.init (0,0,get_width (),get_height ());
                snapshot.append_texture (texture,rect);
            }
        }
        protected override void dispose(){if(error_box.get_parent()!=null)error_box.unparent();base.dispose();}
    }
}
