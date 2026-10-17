namespace MajorisBrowser {
    public class BookmarkFormat : Object {
        public static Gee.ArrayList<Record> parse(string html) throws Error {
            if(html.length>8*1024*1024)throw new BrowserError.STORAGE("Bookmark file exceeds 8 MiB");
            Html.Doc* doc=Html.Doc.read_memory((char[])html.data,html.length,"bookmarks.html","UTF-8",Html.ParserOption.NONET|Html.ParserOption.NOERROR|Html.ParserOption.NOWARNING|Html.ParserOption.RECOVER);
            if(doc==null)throw new BrowserError.STORAGE("Malformed bookmark file");
            var result=new Gee.ArrayList<Record>();walk(doc->get_root_element(),"",result,0);delete doc;return result;
        }
        private static string walk(Xml.Node* node,string folder,Gee.ArrayList<Record> result,int depth){
            if(depth>64 || result.size>=10000)return folder;string current=folder;
            for(Xml.Node* item=node;item!=null;item=item->next){
                if(item->type!=Xml.ElementType.ELEMENT_NODE)continue;
                string name=item->name.down();
                if(name=="h3")current=item->get_content();
                else if(name=="a"){
                    string? href=item->get_prop("href");if(href!=null)try{UrlResolver.web_uri(href);result.add(new Record(0,href,item->get_content(),current));}catch(Error e){}
                }else if(item->children!=null){if(name=="dl"){walk(item->children,current,result,depth+1);current=folder;}else current=walk(item->children,current,result,depth+1);}
                if(result.size>=10000)return current;
            }
            return current;
        }
        public static string export_html(Gee.ArrayList<Record> rows){
            var text=new StringBuilder("<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n<TITLE>Bookmarks</TITLE><H1>Bookmarks</H1><DL><p>\n");
            var folders=new Gee.TreeSet<string>();foreach(var row in rows)folders.add(row.folder);
            foreach(string folder in folders){if(folder!="")text.append("<DT><H3>"+Markup.escape_text(folder)+"</H3><DL><p>\n");foreach(var row in rows)if(row.folder==folder)text.append("<DT><A HREF=\""+Markup.escape_text(row.url)+"\">"+Markup.escape_text(row.title)+"</A>\n");if(folder!="")text.append("</DL><p>\n");}text.append("</DL><p>\n");return text.str;
        }
    }
}
