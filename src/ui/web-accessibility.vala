namespace MajorisBrowser {
    [CCode(cname="gtk_accessible_update_platform_state",cheader_filename="gtk/gtk.h")]
    private extern void accessible_platform_changed(Gtk.Accessible accessible,Gtk.AccessiblePlatformState state);
    // These objects represent CEF AX nodes, never a guessed DOM or a page summary.
    internal class WebAccessibleNode : Object, Gtk.Accessible {
        public Gtk.AccessibleRole accessible_role { get; set; }
        private Gtk.ATContext? context;
        public weak WebAccessibleHost? owner;
        public weak Gtk.Accessible? parent_node;
        public weak WebAccessibleNode? sibling;
        public Gee.ArrayList<WebAccessibleNode> children=new Gee.ArrayList<WebAccessibleNode>();
        public int node_id;
        public string tree="";
        public Json.Object data;
        public WebAccessibleNode(WebAccessibleHost host,int id,Gtk.AccessibleRole role,Json.Object value){Object(accessible_role:role);owner=host;node_id=id;data=value;}
        public Gtk.ATContext? get_at_context(){if(context==null && owner!=null)context=Gtk.ATContext.create(accessible_role,this,owner.get_display());return context;}
        public Gtk.Accessible? get_accessible_parent(){return parent_node;}
        public Gtk.Accessible? get_first_accessible_child(){return children.size>0?children[0]:null;}
        public Gtk.Accessible? get_next_accessible_sibling(){return sibling;}
        public bool get_platform_state(Gtk.AccessiblePlatformState state){
            if(owner==null)return false;
            if(state==Gtk.AccessiblePlatformState.FOCUSED)return owner.surface!=null && owner.surface.has_focus && owner.is_focused(this);
            if(state==Gtk.AccessiblePlatformState.FOCUSABLE)return state_has("focusable");
            return owner.get_mapped();
        }
        public bool get_bounds(out int x,out int y,out int width,out int height){
            x=0;y=0;width=0;height=0;
            if(owner==null || !data.has_member("location"))return false;
            double ax,ay,px=0,py=0;if(!owner.position(this,out ax,out ay))return false;
            var parent=parent_node as WebAccessibleNode;if(parent!=null && !owner.position(parent,out px,out py))return false;
            var rect=data.get_object_member("location");double left=ax-px,top=ay-py,right=left+rect.get_double_member("width"),bottom=top+rect.get_double_member("height");
            x=(int)left;y=(int)top;if(x>left)x--;if(y>top)y--;int end_x=(int)right,end_y=(int)bottom;if(end_x<right)end_x++;if(end_y<bottom)end_y++;width=int.max(0,end_x-x);height=int.max(0,end_y-y);return true;
        }
        public bool state_has(string name){if(!data.has_member("state"))return false;foreach(var value in data.get_array_member("state").get_elements())if(value.get_string()==name)return true;return false;}
        public string attribute(string name){if(!data.has_member("attributes"))return "";var a=data.get_object_member("attributes");if(!a.has_member(name))return "";var v=a.get_member(name);return v.get_value_type()==typeof(string)?v.get_string():Json.to_string(v,false);}
        public void refresh(){
            update_property(Gtk.AccessibleProperty.LABEL,attribute("name"),Gtk.AccessibleProperty.DESCRIPTION,attribute("description"),Gtk.AccessibleProperty.READ_ONLY,attribute("restriction")=="readOnly",Gtk.AccessibleProperty.MULTI_LINE,state_has("multiline"),Gtk.AccessibleProperty.REQUIRED,state_has("required"));
            update_state(Gtk.AccessibleState.DISABLED,attribute("restriction")=="disabled",Gtk.AccessibleState.BUSY,state_has("busy"),Gtk.AccessibleState.HIDDEN,state_has("invisible"));
            string check=attribute("checkedState");if(check!="")update_state(Gtk.AccessibleState.CHECKED,check=="mixed"?Gtk.AccessibleTristate.MIXED:check=="true"?Gtk.AccessibleTristate.TRUE:Gtk.AccessibleTristate.FALSE);
            if(state_has("expanded") || state_has("collapsed"))update_state(Gtk.AccessibleState.EXPANDED,state_has("expanded"));
            update_state(Gtk.AccessibleState.SELECTED,state_has("selected"));
            update_property(Gtk.AccessibleProperty.PLACEHOLDER,attribute("placeholder"),Gtk.AccessibleProperty.ROLE_DESCRIPTION,attribute("roleDescription"),Gtk.AccessibleProperty.KEY_SHORTCUTS,attribute("keyShortcuts"));
            if(attribute("hierarchicalLevel")!="")update_property(Gtk.AccessibleProperty.LEVEL,int.parse(attribute("hierarchicalLevel")));
            if(attribute("valueForRange")!="")update_property(Gtk.AccessibleProperty.VALUE_NOW,double.parse(attribute("valueForRange")),Gtk.AccessibleProperty.VALUE_MIN,double.parse(attribute("minValueForRange")),Gtk.AccessibleProperty.VALUE_MAX,double.parse(attribute("maxValueForRange")));
        }
    }
    internal class WebAccessibleTextNode : WebAccessibleNode, Gtk.AccessibleText {
        private string text="";
        public WebAccessibleTextNode(WebAccessibleHost host,int id,Gtk.AccessibleRole role,Json.Object data){base(host,id,role,data);}
        private uint char_offset(int units){uint result=0;int consumed=0;for(int i=0;i<text.char_count() && consumed<units;i++){unichar c=text.get_char(text.index_of_nth_char(i));consumed+=c>0xffff?2:1;result++;}return result;}
        public void refresh_text(){
            string next="";if(owner!=null && !owner.protected_text(this)){if(data.get_string_member("role")=="textField" || data.get_string_member("role")=="searchBox"){next=attribute("value");if(attribute("nonAtomicTextFieldRoot")=="true")next=owner.editable_text(this);}else next=attribute("name");}
            if(next!=text){uint old=(uint)text.char_count();if(old>0)update_contents(Gtk.AccessibleTextContentChange.REMOVE,0,old);text=next;if(text!="")update_contents(Gtk.AccessibleTextContentChange.INSERT,0,(uint)text.char_count());if(old>0 && attribute("containerLiveStatus")!="" && text!="")announce(text,attribute("containerLiveStatus")=="assertive"?Gtk.AccessibleAnnouncementPriority.HIGH:Gtk.AccessibleAnnouncementPriority.MEDIUM);}
            update_caret_position();update_selection_bound();
        }
        public bool get_accessible_text_attributes(uint offset,[CCode(array_length_pos=1.5,array_length_type="gsize")] out Gtk.AccessibleTextRange[] ranges,[CCode(array_length=false,array_null_terminated=true)] out string[] names,[CCode(array_length=false,array_null_terminated=true)] out string[] values){ranges={};names={};values={};return false;}
        public uint get_caret_position(){return char_offset(int.parse(attribute("textSelEnd")));}
        public Bytes get_contents(uint start,uint end){uint length=(uint)text.char_count();start=uint.min(start,length);end=uint.min(end,length);if(end<start)end=start;string value=text.substring(text.index_of_nth_char((int)start),text.index_of_nth_char((int)end)-text.index_of_nth_char((int)start));uint8[] bytes=new uint8[value.length+1];Memory.copy(bytes,value.data,value.length);return new Bytes(bytes);}
        public Bytes get_contents_at(uint offset,Gtk.AccessibleTextGranularity granularity,out uint start,out uint end){
            uint length=(uint)text.char_count();start=uint.min(offset,length);end=start;
            if(start==length)return get_contents(start,end);
            if(granularity==Gtk.AccessibleTextGranularity.CHARACTER)end=start+1;
            else { // Unicode word and sentence boundaries are supplied by Pango.
                Pango.LogAttr[] attrs=new Pango.LogAttr[length+1];Pango.get_log_attrs(text,-1,-1,Pango.Language.get_default(),attrs);
                if(granularity==Gtk.AccessibleTextGranularity.WORD){while(start>0 && attrs[start].is_word_start==0 && attrs[start].is_word_end==0)start--;end=uint.min(offset+1,length);while(end<length && attrs[end].is_word_end==0 && attrs[end].is_word_start==0)end++;}
                else if(granularity==Gtk.AccessibleTextGranularity.SENTENCE){while(start>0 && attrs[start].is_sentence_start==0)start--;end=uint.min(offset+1,length);while(end<length && attrs[end].is_sentence_end==0)end++;}
                else {while(start>0 && text.get_char(text.index_of_nth_char((int)start-1))!='\n')start--;end=uint.min(offset+1,length);while(end<length && text.get_char(text.index_of_nth_char((int)end-1))!='\n')end++;}
            }return get_contents(start,end);
        }
        public bool get_selection([CCode(array_length_pos=0.5,array_length_type="gsize")] out Gtk.AccessibleTextRange[] ranges){ranges={};uint a=char_offset(int.parse(attribute("textSelStart"))),b=char_offset(int.parse(attribute("textSelEnd")));if(a==b)return false;Gtk.AccessibleTextRange range={uint.min(a,b),a>b?a-b:b-a};ranges={range};return true;}
    }
    internal class WebAccessibleHost : Gtk.Widget, Gtk.Accessible {
        public weak BrowserSurface? surface;
        private Gee.HashMap<string,WebAccessibleNode> nodes=new Gee.HashMap<string,WebAccessibleNode>();
        private Gee.HashMap<string,int> roots=new Gee.HashMap<string,int>();
        private Gee.HashMap<string,int> focuses=new Gee.HashMap<string,int>();
        private string focus_tree="";
        private WebAccessibleNode? root_node;
        private string tree_id="";
        public WebAccessibleHost(BrowserSurface source){surface=source;can_target=false;focusable=false;source.notify["has-focus"].connect(()=>{foreach(var node in nodes.values)if(node.parent_node!=null)accessible_platform_changed(node,Gtk.AccessiblePlatformState.FOCUSED);});}
        public new Gtk.Accessible? get_first_accessible_child(){return root_node;}
        public bool protected_text(WebAccessibleNode node){
            WebAccessibleNode? current=node;int depth=0;while(current!=null && depth++<128){if(current.state_has("protected") || current.attribute("inputType")=="password")return true;current=current.parent_node as WebAccessibleNode;}return false;
        }
        public string editable_text(WebAccessibleNode node){var text=new StringBuilder();var seen=new Gee.HashSet<string>();append_text(node,text,seen,0);return text.len<=1024*1024?text.str:"";}
        private void append_text(WebAccessibleNode node,StringBuilder text,Gee.HashSet<string> seen,int depth){
            string key=node.tree+":"+node.node_id.to_string();if(depth>128 || seen.contains(key) || text.len>1024*1024 || protected_text(node))return;seen.add(key);
            string role=node.data.get_string_member("role");if(role=="staticText"){text.append(node.attribute("name"));return;}if(role=="lineBreak"){text.append("\n");return;}
            if(node.data.has_member("child_ids"))foreach(var id in node.data.get_array_member("child_ids").get_elements()){var child=nodes[node.tree+":"+id.get_int().to_string()];if(child!=null)append_text(child,text,seen,depth+1);}
        }
        public bool position(WebAccessibleNode node,out double x,out double y){
            x=0;y=0;if(node.tree!=tree_id)return false;var seen=new Gee.HashSet<int>();WebAccessibleNode? current=node;
            while(current!=null){if(seen.size>128 || seen.contains(current.node_id) || current.data.has_member("transform") || !current.data.has_member("location"))return false;seen.add(current.node_id);var location=current.data.get_object_member("location");x+=location.get_double_member("x");y+=location.get_double_member("y");if(!current.data.has_member("offset_container_id"))return current==root_node;
                int offset=(int)current.data.get_int_member("offset_container_id");if(offset<=0)return current==root_node;current=nodes[current.tree+":"+offset.to_string()];if(current==null)return false;x-=double.parse(current.attribute("scrollX"));y-=double.parse(current.attribute("scrollY"));
            }return false;
        }
        public void clear(){foreach(var node in nodes.values){node.set_accessible_parent(null,null);node.children.clear();}nodes.clear();root_node=null;tree_id="";roots.clear();focuses.clear();focus_tree="";}
        private static Gtk.AccessibleRole role(string value){switch(value){
            case "rootWebArea":return Gtk.AccessibleRole.DOCUMENT;case "heading":return Gtk.AccessibleRole.HEADING;
            case "textField":case "searchBox":return Gtk.AccessibleRole.TEXT_BOX;case "staticText":return Gtk.AccessibleRole.LABEL;
            case "button":return Gtk.AccessibleRole.BUTTON;case "checkBox":return Gtk.AccessibleRole.CHECKBOX;case "radioButton":return Gtk.AccessibleRole.RADIO;
            case "link":return Gtk.AccessibleRole.LINK;case "image":return Gtk.AccessibleRole.IMG;case "list":return Gtk.AccessibleRole.LIST;case "listItem":return Gtk.AccessibleRole.LIST_ITEM;
            case "table":return Gtk.AccessibleRole.TABLE;case "row":return Gtk.AccessibleRole.ROW;case "cell":return Gtk.AccessibleRole.CELL;
            case "dialog":return Gtk.AccessibleRole.DIALOG;case "alert":return Gtk.AccessibleRole.ALERT;case "status":return Gtk.AccessibleRole.STATUS;
            case "slider":return Gtk.AccessibleRole.SLIDER;case "progressIndicator":return Gtk.AccessibleRole.PROGRESS_BAR;case "comboBoxSelect":return Gtk.AccessibleRole.COMBO_BOX;
            case "listBox":return Gtk.AccessibleRole.LIST_BOX;case "listBoxOption":case "menuListOption":return Gtk.AccessibleRole.OPTION;
            case "tab":return Gtk.AccessibleRole.TAB;case "tabList":return Gtk.AccessibleRole.TAB_LIST;case "tabPanel":return Gtk.AccessibleRole.TAB_PANEL;
            case "tree":return Gtk.AccessibleRole.TREE;case "treeItem":return Gtk.AccessibleRole.TREE_ITEM;case "treeGrid":return Gtk.AccessibleRole.TREE_GRID;
            case "menu":return Gtk.AccessibleRole.MENU;case "menuBar":return Gtk.AccessibleRole.MENU_BAR;case "menuItem":return Gtk.AccessibleRole.MENU_ITEM;
            case "menuItemCheckBox":return Gtk.AccessibleRole.MENU_ITEM_CHECKBOX;case "menuItemRadio":return Gtk.AccessibleRole.MENU_ITEM_RADIO;
            case "columnHeader":return Gtk.AccessibleRole.COLUMN_HEADER;case "rowHeader":return Gtk.AccessibleRole.ROW_HEADER;case "rowGroup":return Gtk.AccessibleRole.ROW_GROUP;
            case "grid":return Gtk.AccessibleRole.GRID;case "gridCell":return Gtk.AccessibleRole.GRID_CELL;
            case "main":return Gtk.AccessibleRole.MAIN;case "navigation":return Gtk.AccessibleRole.NAVIGATION;case "banner":return Gtk.AccessibleRole.BANNER;
            case "form":return Gtk.AccessibleRole.FORM;case "article":return Gtk.AccessibleRole.ARTICLE;case "paragraph":return Gtk.AccessibleRole.PARAGRAPH;case "blockquote":return Gtk.AccessibleRole.BLOCK_QUOTE;
            case "search":return Gtk.AccessibleRole.SEARCH;case "region":return Gtk.AccessibleRole.REGION;case "note":return Gtk.AccessibleRole.NOTE;
            case "toolbar":return Gtk.AccessibleRole.TOOLBAR;case "tooltip":return Gtk.AccessibleRole.TOOLTIP;case "separator":return Gtk.AccessibleRole.SEPARATOR;
            case "spinButton":return Gtk.AccessibleRole.SPIN_BUTTON;case "switch":return Gtk.AccessibleRole.SWITCH;case "radioGroup":return Gtk.AccessibleRole.RADIO_GROUP;
            case "alertDialog":return Gtk.AccessibleRole.ALERT_DIALOG;case "log":return Gtk.AccessibleRole.LOG;case "meter":return Gtk.AccessibleRole.METER;
            default:return Gtk.AccessibleRole.GROUP;}}
        public void consume(string json){
            try{var parser=new Json.Parser();parser.load_from_data(json);var obj=parser.get_root().get_object();string id=obj.get_string_member("ax_tree_id");
                if(!obj.has_member("updates"))return;
                foreach(var entry in obj.get_array_member("updates").get_elements()){
                    var update=entry.get_object();if(update.has_member("tree_data")){var td=update.get_object_member("tree_data");if(tree_id=="" && td.has_member("url") && surface!=null && td.get_string_member("url")==surface.url)tree_id=id;if(td.has_member("focus_id"))focuses[id]=(int)td.get_int_member("focus_id");if(id==tree_id && td.has_member("focused_tree_id"))focus_tree=td.get_string_member("focused_tree_id");}
                    if(update.has_member("root_id"))roots[id]=(int)update.get_int_member("root_id");
                    if(update.has_member("nodes"))foreach(var item in update.get_array_member("nodes").get_elements()){
                        var data=item.get_object();int key=(int)data.get_int_member("id");string r=data.get_string_member("role");var mapped=role(r);string identity=id+":"+key.to_string();var node=nodes[identity];
                        if(node==null || node.accessible_role!=mapped){if(node!=null)node.set_accessible_parent(null,null);node=r=="textField" || r=="searchBox" || r=="staticText"?new WebAccessibleTextNode(this,key,mapped,data):new WebAccessibleNode(this,key,mapped,data);node.tree=id;nodes[identity]=node;}
                        node.data=data;
                    }
                }
                if(nodes.size>20000){clear();return;}
                var visited=new Gee.HashSet<string>();root_node=nodes[tree_id+":"+roots[tree_id].to_string()];if(root_node!=null)connect_tree(root_node,this,null,visited,0);
                // Non-atomic editable roots store text in AX staticText children,
                // not in a value attribute. Refresh after all nodes and parents exist.
                foreach(string key in visited){var node=nodes[key];node.refresh();var text=node as WebAccessibleTextNode;if(text!=null)text.refresh_text();if(!node.state_has("protected") && protected_text(node))node.update_property(Gtk.AccessibleProperty.LABEL,"");}
                // A subframe update may precede its parent's childTreeId. Bound orphan
                // retention and prune detached nodes within each updated engine tree.
                var local=new Gee.HashSet<string>();var local_root=nodes[id+":"+roots[id].to_string()];if(local_root!=null)mark_tree(local_root,local,0);
                foreach(string key in nodes.keys.to_array())if(key.has_prefix(id+":") && !local.contains(key)){nodes[key].set_accessible_parent(null,null);nodes.unset(key);}
                foreach(string key in visited)accessible_platform_changed(nodes[key],Gtk.AccessiblePlatformState.FOCUSED);
            }catch(Error e){warning("Invalid engine accessibility update: %s",e.message);}
        }
        public void consume_locations(string json){
            try{var parser=new Json.Parser();parser.load_from_data(json);if(parser.get_root().get_node_type()!=Json.NodeType.ARRAY)return;foreach(var item in parser.get_root().get_array().get_elements()){var entry=item.get_object();string key=entry.get_string_member("ax_tree_id")+":"+entry.get_int_member("id").to_string();var node=nodes[key];if(node==null || !entry.has_member("new_location"))continue;var location=entry.get_object_member("new_location");if(location.has_member("bounds"))node.data.set_object_member("location",location.get_object_member("bounds"));if(location.has_member("offset_container_id"))node.data.set_int_member("offset_container_id",location.get_int_member("offset_container_id"));if(node.data.has_member("transform"))node.data.remove_member("transform");if(location.has_member("transform"))node.data.set_member("transform",location.get_member("transform").copy());}}
            catch(Error e){warning("Invalid engine accessibility location update: %s",e.message);}
        }
        public bool is_focused(WebAccessibleNode node){return node.tree==(focus_tree==""?tree_id:focus_tree) && focuses.has_key(node.tree) && focuses[node.tree]==node.node_id;}
        private void mark_tree(WebAccessibleNode node,Gee.HashSet<string> visited,int depth){string identity=node.tree+":"+node.node_id.to_string();if(depth>128 || visited.contains(identity))return;visited.add(identity);if(node.data.has_member("child_ids"))foreach(var item in node.data.get_array_member("child_ids").get_elements()){var child=nodes[node.tree+":"+item.get_int().to_string()];if(child!=null)mark_tree(child,visited,depth+1);}}
        private void connect_tree(WebAccessibleNode node,Gtk.Accessible parent,WebAccessibleNode? next,Gee.HashSet<string> visited,int depth){
            string identity=node.tree+":"+node.node_id.to_string();if(depth>128 || visited.contains(identity))return;visited.add(identity);
            if(node.parent_node!=parent || node.sibling!=next){node.parent_node=parent;node.sibling=next;node.set_accessible_parent(parent,next);}
            node.children.clear();if(node.data.has_member("child_ids"))foreach(var item in node.data.get_array_member("child_ids").get_elements()){var child=nodes[node.tree+":"+item.get_int().to_string()];if(child!=null && child.data.get_string_member("role")!="inlineTextBox" && !visited.contains(child.tree+":"+child.node_id.to_string()))node.children.add(child);}
            string child_tree=node.attribute("childTreeId");if(child_tree!="" && roots.has_key(child_tree)){var frame=nodes[child_tree+":"+roots[child_tree].to_string()];if(frame!=null)node.children.add(frame);}
            for(int i=0;i<node.children.size;i++)connect_tree(node.children[i],node,i+1<node.children.size?node.children[i+1]:null,visited,depth+1);
        }
    }
}
