namespace MajorisBrowser {
    public class ProfileImport : Object {
        public static int chromium_bookmarks(Store store,string text) throws Error {
            if(text.length>8*1024*1024)throw new BrowserError.STORAGE("Bookmark file exceeds 8 MiB");var parser=new Json.Parser();parser.load_from_data(text);var roots=parser.get_root().get_object().get_object_member("roots");int count=0;foreach(string name in roots.get_members())walk(store,roots.get_object_member(name),"",0,ref count);return count;
        }
        private static void walk(Store store,Json.Object node,string folder,int depth,ref int count) throws Error {
            if(depth>64 || count>=10000)return;
            if(node.has_member("type") && node.get_string_member("type")=="url"){
                string url=node.get_string_member("url");try{UrlResolver.web_uri(url);}catch(Error e){return;}store.bookmark(url,node.get_string_member("name"),folder);count++;
            }else if(node.has_member("children")){
                string name=node.has_member("name")?node.get_string_member("name"):"";string path=folder==""?name:folder+" / "+name;foreach(var child in node.get_array_member("children").get_elements())walk(store,child.get_object(),path,depth+1,ref count);
            }
        }
        public static int history(Store store,string path,bool firefox) throws Error {
            // A closed-browser snapshot avoids creating or modifying source WAL/SHM files.
            if(FileUtils.test(path+"-wal",FileTest.EXISTS) || FileUtils.test(path+"-journal",FileTest.EXISTS))throw new BrowserError.STORAGE("Close the source browser before importing history");
            var file=File.new_for_path(path);if(file.query_info(FileAttribute.STANDARD_SIZE,FileQueryInfoFlags.NOFOLLOW_SYMLINKS).get_size()>512*1024*1024)throw new BrowserError.STORAGE("History database exceeds 512 MiB");
            string temp=DirUtils.make_tmp("majoris-history-import-XXXXXX"),copy=Path.build_filename(temp,"history.db");int count=0;
            try{
                file.copy(File.new_for_path(copy),FileCopyFlags.NONE,null,null);Sqlite.Database source;if(Sqlite.Database.open_v2(copy,out source,Sqlite.OPEN_READONLY)!=Sqlite.OK)throw new BrowserError.STORAGE("Cannot read source history");Sqlite.Statement query;
                string sql=firefox?"SELECT url,COALESCE(title,''),last_visit_date/1000000 FROM moz_places WHERE last_visit_date IS NOT NULL LIMIT 100000":"SELECT url,title,last_visit_time/1000000-11644473600 FROM urls LIMIT 100000";
                if(source.prepare_v2(sql,-1,out query)!=Sqlite.OK)throw new BrowserError.STORAGE("Unsupported browser history format");int result;while((result=query.step())==Sqlite.ROW){string url=query.column_text(0);try{UrlResolver.web_uri(url);}catch(Error e){continue;}store.imported_visit(url,query.column_text(1),query.column_int64(2));count++;}if(result!=Sqlite.DONE)throw new BrowserError.STORAGE("Source history could not be read");
            }finally{FileUtils.remove(copy);DirUtils.remove(temp);}return count;
        }
        public static int firefox_bookmarks(Store store,string path) throws Error {
            if(FileUtils.test(path+"-wal",FileTest.EXISTS) || FileUtils.test(path+"-journal",FileTest.EXISTS))throw new BrowserError.STORAGE("Close the source browser before importing its active places database");
            var file=File.new_for_path(path);var before=file.query_info("standard::size,time::modified,time::modified-usec",FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            if(before.get_size()>512*1024*1024)throw new BrowserError.STORAGE("Bookmark database exceeds 512 MiB");
            string temp=DirUtils.make_tmp("majoris-bookmark-import-XXXXXX"),copy=Path.build_filename(temp,"places.db");int count=0;
            try{
                file.copy(File.new_for_path(copy),FileCopyFlags.NONE,null,null);var after=file.query_info("standard::size,time::modified,time::modified-usec",FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                if(FileUtils.test(path+"-wal",FileTest.EXISTS) || FileUtils.test(path+"-journal",FileTest.EXISTS) || before.get_size()!=after.get_size() || before.get_attribute_uint64("time::modified")!=after.get_attribute_uint64("time::modified") || before.get_attribute_uint32("time::modified-usec")!=after.get_attribute_uint32("time::modified-usec"))throw new BrowserError.STORAGE("Source bookmarks changed during import; close that browser and retry");
                Sqlite.Database source;if(Sqlite.Database.open_v2(copy,out source,Sqlite.OPEN_READONLY)!=Sqlite.OK)throw new BrowserError.STORAGE("Cannot read Firefox bookmarks");source.exec("PRAGMA query_only=ON; PRAGMA trusted_schema=OFF");Sqlite.Statement query;
                string sql="WITH RECURSIVE folders(id,path,depth) AS (SELECT id,COALESCE(title,''),0 FROM moz_bookmarks WHERE parent=0 UNION ALL SELECT b.id,CASE WHEN f.path='' THEN COALESCE(b.title,'') ELSE f.path||' / '||COALESCE(b.title,'') END,f.depth+1 FROM moz_bookmarks b JOIN folders f ON b.parent=f.id WHERE b.type=2 AND f.depth<64) SELECT p.url,COALESCE(b.title,p.title,''),COALESCE(f.path,'') FROM moz_bookmarks b JOIN moz_places p ON p.id=b.fk LEFT JOIN folders f ON f.id=b.parent WHERE b.type=1 LIMIT 100000";
                if(source.prepare_v2(sql,-1,out query)!=Sqlite.OK)throw new BrowserError.STORAGE("Unsupported Firefox bookmark schema");int result;while((result=query.step())==Sqlite.ROW){string url=query.column_text(0);try{UrlResolver.web_uri(url);}catch(Error e){continue;}store.bookmark(url,query.column_text(1),query.column_text(2));count++;}if(result!=Sqlite.DONE)throw new BrowserError.STORAGE("Firefox bookmarks could not be read");
            }finally{FileUtils.remove(copy);DirUtils.remove(temp);}return count;
        }
    }
}
