namespace MajorisBrowser {
    public delegate void PageOpener(string url,bool new_window);
    public class PageContextMenu : Object {
        private delegate void MenuAction();
        private Menu menu=new Menu();
        private SimpleActionGroup actions=new SimpleActionGroup();
        private int count;
        private BrowserSurface surface;
        private string generation="";
        public static void show(Application app,BrowserSurface surface,string text,owned PageOpener opener){new PageContextMenu(app,surface,text,(owned)opener);}
        private void item(string label,owned MenuAction callback,bool enabled=true){string name="item"+(count++).to_string();var action=new SimpleAction(name,null);action.set_enabled(enabled);action.activate.connect(()=>callback());actions.add_action(action);menu.append(label,"page-context."+name);}
        private void command(string label,string command,bool enabled=true){item(label,()=>surface.engine.command(command),enabled);}
        private PageContextMenu(Application app,BrowserSurface surface,string text,owned PageOpener opener){
            this.surface=surface;
            try{
                var parser=new Json.Parser();parser.load_from_data(text);var data=parser.get_root().get_object();
                generation=data.has_member("generation")?data.get_string_member("generation"):"";
                string link=data.get_string_member("link"),source=data.get_string_member("source"),selection=data.get_string_member("selection");bool editable=data.get_boolean_member("editable");int edit=(int)data.get_int_member("editFlags"),media=(int)data.get_int_member("media"),flags=(int)data.get_int_member("mediaFlags");
                bool background=!editable && selection=="" && link=="" && media==0;
                if(background){command(_("Back"),"back",surface.can_go_back);command(_("Forward"),"forward",surface.can_go_forward);command(_("Reload"),"reload");command(_("Save Page As…"),"save-page");command(_("Print…"),"print");command(_("View Source"),"view-source");}
                if(link!=""){
                    bool web=false;try{UrlResolver.web_uri(link);web=true;}catch(Error e){}
                    if(web){item(_("Open Link"),()=>surface.navigate(link));if(app.webapp==null)item(_("Open in New Tab"),()=>opener(link,false));item(_("Open in New Window"),()=>opener(link,true));command(_("Save Link…"),"download:"+link);}
                    item(_("Copy Link"),()=>surface.get_clipboard().set_text(link));
                }
                if(media==1 && source!=""){
                    bool navigable=false;try{UrlResolver.web_uri(source);navigable=true;}catch(Error e){}
                    if(navigable)item(_("Open Image"),()=>opener(source,false));if((flags&16)!=0)command(_("Save Image…"),"download:"+source);command(_("Copy Image"),"copy-context-image");item(_("Copy Image Address"),()=>surface.get_clipboard().set_text(source));
                }
                if(editable){
                    string[] labels={_("Undo"),_("Redo"),_("Cut"),_("Copy"),_("Paste"),_("Select All")};string[] commands={"undo","redo","cut","copy","paste","select-all"};int[] bits={1,2,4,8,16,64};for(int i=0;i<bits.length;i++)if((edit&bits[i])!=0)command(labels[i],commands[i]);
                    foreach(var node in data.get_array_member("suggestions").get_elements()){string suggestion=node.get_string();command(suggestion,"spell:"+suggestion);}
                }else if(selection!="")command(_("Copy"),"copy");
                if(selection!="" && selection.length<=8192){string target=app.preferences.get_string("search-template").replace("%s",Uri.escape_string(selection,null,false));item(_("Search Selected Text"),()=>opener(target,false));}
                if((media==2 || media==3) && (flags&1)==0){
                    if(media==2 && MajorisCef.has_native_pip())command(_("Picture in Picture"),"context-media:"+generation+":pip");
                    command((flags&2)!=0?_("Play"):_("Pause"),"context-media:"+generation+((flags&2)!=0?":play":":pause"));
                    if((flags&32)!=0)command((flags&4)!=0?_("Unmute Media"):_("Mute Media"),"context-media:"+generation+((flags&4)!=0?":unmute":":mute"));
                    if(source!=""){item(_("Open Media"),()=>opener(source,false));if((flags&16)!=0)command(_("Save Media…"),"download:"+source);item(_("Copy Media URL"),()=>surface.get_clipboard().set_text(source));}

                }
                command(_("Inspect"),"inspect-context");
                surface.insert_action_group("page-context",actions);var popover=new Gtk.PopoverMenu.from_model(menu);popover.set_parent(surface);Gdk.Rectangle point={(int)data.get_int_member("x"),(int)data.get_int_member("y"),1,1};popover.pointing_to=point;popover.closed.connect(()=>{popover.unparent();surface.insert_action_group("page-context",null);});popover.popup();
            }catch(Error e){EngineDialogs.show_error(surface,e.message);}
        }
    }
}
