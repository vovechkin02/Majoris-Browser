namespace MajorisBrowser {
    public abstract class BrowserSurface : Gtk.Widget {
        public MajorisCef.View engine { get; protected set; }
        public string url = "about:blank";
        public string page_title = "New Tab";
        public bool has_frame;
        public signal void changed (string kind, string value);
        public void close () { engine.close (); }
        public void navigate (string target) { engine.load (target); }
    }
    public class OffscreenBrowserSurface : BrowserSurface {
        private Gdk.Texture? texture;
        private Gtk.IMMulticontext im;
        private double pointer_x;
        private double pointer_y;
        public OffscreenBrowserSurface (string profile, bool ephemeral, string target, string scope = "") {
            hexpand = true; vexpand = true; focusable = true;
            engine = new MajorisCef.View (profile, ephemeral, target, scope);
            engine.frame.connect ((bytes,w,h) => {
                has_frame=true;
                texture = new Gdk.MemoryTexture (w,h,Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED,bytes,w*4);
                queue_draw ();
            });
            engine.event.connect ((kind,value) => {
                if (kind == "url") url = value;
                if (kind == "title") page_title = value;
                if (kind == "tooltip") tooltip_text = value;
                if (kind == "cursor") set_cursor_from_name (value);
                if (kind == "ready") engine.resize (get_width (),get_height (),get_scale_factor ());
                changed (kind,value);
            });
            im = new Gtk.IMMulticontext (); im.set_client_widget (this);
            im.commit.connect ((text) => engine.text (text));
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
                if ((state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK)) == 0) {
                    unichar c = Gdk.keyval_to_unicode (key);
                    if (c >= 32) engine.text (c.to_string ());
                }
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
            engine.resize (width,height,get_scale_factor ());
        }
        public override void snapshot (Gtk.Snapshot snapshot) {
            if (texture != null) {
                Graphene.Rect rect = Graphene.Rect (); rect.init (0,0,get_width (),get_height ());
                snapshot.append_texture (texture,rect);
            }
        }
    }
}
