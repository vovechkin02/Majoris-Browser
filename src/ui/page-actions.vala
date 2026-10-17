namespace MajorisBrowser {
    public class PageActions : Object {
        private Gtk.PrintDialog printer=new Gtk.PrintDialog();
        private Gtk.PrintSetup? setup;
        public static void attach(BrowserSurface surface){new PageActions(surface);}
        private PageActions(BrowserSurface surface){
            surface.changed.connect((kind,value)=>{if(kind=="save-pdf" || kind=="save-page")output.begin(surface,kind,value);if(kind=="print-reset")setup=null;});
            surface.engine.request.connect((token,kind,origin,message)=>{if(kind=="print-setup" || kind=="print-job")print_request.begin(surface,token,kind,message);});
        }
        private async void print_request(BrowserSurface surface,int token,string kind,string path){
            if(surface.closed){surface.engine.reply(token,false,"");return;}
            var cancel=new Cancellable();ulong closing=surface.notify["closed"].connect(()=>{if(surface.closed)cancel.cancel();});
            try{
                var window=surface.get_root() as Gtk.Window;if(window==null)throw new IOError.CLOSED("Page was closed");
                if(kind=="print-setup"){
                    setup=yield printer.setup(window,cancel);if(setup==null)throw new IOError.CANCELLED("Printing was cancelled");var page=setup.get_page_setup();
                    var b=new Json.Builder();b.begin_object();b.set_member_name("width");b.add_int_value((int)(page.get_paper_width(Gtk.Unit.POINTS)*300/72));b.set_member_name("height");b.add_int_value((int)(page.get_paper_height(Gtk.Unit.POINTS)*300/72));b.set_member_name("landscape");b.add_boolean_value(page.get_orientation()==Gtk.PageOrientation.LANDSCAPE || page.get_orientation()==Gtk.PageOrientation.REVERSE_LANDSCAPE);b.end_object();var g=new Json.Generator();g.set_root(b.get_root());surface.engine.reply(token,!surface.closed,g.to_data(null));
                }else{yield printer.print_file(window,setup,File.new_for_path(path),cancel);surface.engine.reply(token,true,"");}
            }catch(Error e){surface.engine.reply(token,false,"");if(!(e is Gtk.DialogError.DISMISSED) && !(e is IOError.CANCELLED) && !surface.closed)EngineDialogs.show_error(surface,e.message);}
            surface.disconnect(closing);
        }
        private static async void output(BrowserSurface surface,string kind,string data){
            string? temporary=null;
            try{
                var window=surface.get_root() as Gtk.Window;if(window==null)return;
                uint8[] bytes=kind=="save-page"?data.data:Base64.decode(data);
                if(kind=="print"){
                    temporary=DirUtils.make_tmp("majoris-print-XXXXXX");var file=File.new_for_path(Path.build_filename(temporary,"document.pdf"));yield file.replace_contents_async(bytes,null,false,FileCreateFlags.PRIVATE,null,null);
                    var dialog=new Gtk.PrintDialog();dialog.title=_("Print Page");yield dialog.print_file(window,null,file,null);
                }else{
                    var dialog=new Gtk.FileDialog();dialog.initial_name=kind=="save-page"?"page.mhtml":"page.pdf";var target=yield dialog.save(window,null);yield target.replace_contents_async(bytes,null,false,FileCreateFlags.PRIVATE,null,null);
                }
            }catch(Error e){if(!(e is Gtk.DialogError.DISMISSED) && !surface.closed)EngineDialogs.show_error(surface,e.message);}
            finally{if(temporary!=null){FileUtils.remove(Path.build_filename(temporary,"document.pdf"));DirUtils.remove(temporary);}}
        }
    }
}
