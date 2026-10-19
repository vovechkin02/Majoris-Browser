// Narrow public GtkEditable binding. GTK's C interface has get_text but no
// set_text vfunc: gtk_editable_set_text uses its insert/delete transaction.
// The distro gtk4.vapi models text as a virtual get/set property, which emits
// a nonexistent GtkEditableInterface.set_text when implemented in Vala.
namespace MajorisBrowser {
    [CCode(cheader_filename="gtk/gtk.h",cname="GtkEditable",type_cname="GtkEditableInterface",type_id="gtk_editable_get_type ()",lower_case_cprefix="gtk_editable_")]
    public interface NativeEditable : Gtk.Widget {
        public abstract unowned NativeEditable? get_delegate();
        public abstract unowned string get_text();
        public abstract bool get_selection_bounds(out int start_pos,out int end_pos);
        [CCode(cname="gtk_editable_select_region",vfunc_name="set_selection_bounds")]
        public abstract void select_region(int start_pos,int end_pos);
        [CCode(cname="gtk_editable_insert_text",vfunc_name="insert_text")]
        public abstract void do_insert_text(string text,int length,ref int position);
        [CCode(cname="gtk_editable_delete_text",vfunc_name="delete_text")]
        public abstract void do_delete_text(int start_pos,int end_pos);
        [NoAccessorMethod] public abstract string text {get;set;}
        [NoAccessorMethod] public abstract bool editable {get;set;}
        [NoAccessorMethod] public abstract bool enable_undo {get;set;}
        [NoAccessorMethod] public abstract int width_chars {get;set;}
        [NoAccessorMethod] public abstract int max_width_chars {get;set;}
        [NoAccessorMethod] public abstract float xalign {get;set;}
        [NoAccessorMethod] public abstract int cursor_position {get;}
        [NoAccessorMethod] public abstract int selection_bound {get;}
    }
}
