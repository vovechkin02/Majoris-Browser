namespace MajorisBrowser {
    public class WebAppManager : Object {
        public static void update_icon(Store store,WebApp metadata,string source,string data_home) throws Error {
            if(!ProfilePaths.valid_id(metadata.id))throw new BrowserError.INVALID_APP("Invalid application identity");
            var file=File.new_for_path(source);if(file.query_info(FileAttribute.STANDARD_SIZE,FileQueryInfoFlags.NONE).get_size()>2*1024*1024)throw new BrowserError.INVALID_APP("Icon exceeds 2 MiB");
            int width,height;if(Gdk.Pixbuf.get_file_info(source,out width,out height)==null || width<1 || height<1 || width>4096 || height>4096)throw new BrowserError.INVALID_APP("Unsupported icon dimensions");
            var image=new Gdk.Pixbuf.from_file_at_scale(source,256,256,true);uint8[] png;image.save_to_bufferv(out png,"png",null,null);
            string directory=Path.build_filename(data_home,"icons","hicolor","256x256","apps");if(DirUtils.create_with_parents(directory,0700)!=0)throw new FileError.FAILED("Cannot create icon directory");string target=Path.build_filename(directory,metadata.application_id+".png"),old=metadata.icon_path;uint8[]? backup=null;if(FileUtils.test(target,FileTest.EXISTS))FileUtils.get_data(target,out backup);
            try{File.new_for_path(target).replace_contents(png,null,false,FileCreateFlags.PRIVATE,null);metadata.icon_path=target;store.put_app(metadata);metadata.install_desktop(data_home);}
            catch(Error e){metadata.icon_path=old;store.put_app(metadata);if(backup!=null)File.new_for_path(target).replace_contents(backup,null,false,FileCreateFlags.PRIVATE,null);else FileUtils.remove(target);throw e;}
            string svg=Path.build_filename(data_home,"icons","hicolor","scalable","apps",metadata.application_id+".svg");if(old==svg)FileUtils.remove(svg);
        }
        public static async uint64 measure(string profile) throws Error {
            uint64 result=0;Error? failure=null;SourceFunc resume=measure.callback;
            new Thread<void*>("app-profile-size",()=>{try{int count=0;result=measure_files(File.new_for_path(profile),0,ref count);}catch(Error e){failure=e;}Idle.add((owned)resume);return null;});yield;if(failure!=null)throw failure;return result;
        }
        private static uint64 measure_files(File file,int depth,ref int count) throws Error {
            if(depth>64 || ++count>100000)throw new IOError.FAILED("Profile file count exceeds measurement limit");
            var info=file.query_info("standard::type,standard::size",FileQueryInfoFlags.NOFOLLOW_SYMLINKS);if(info.get_file_type()==FileType.SYMBOLIC_LINK)return 0;if(info.get_file_type()!=FileType.DIRECTORY)return (uint64)info.get_size();
            uint64 total=0;var children=file.enumerate_children(FileAttribute.STANDARD_NAME,FileQueryInfoFlags.NOFOLLOW_SYMLINKS);FileInfo? child;while((child=children.next_file())!=null)total+=measure_files(file.get_child(child.get_name()),depth+1,ref count);children.close();return total;
        }
        public static void rename(Store store,WebApp metadata,string name,string data_home) throws Error {
            if(name.strip()=="")throw new BrowserError.INVALID_APP("Application name is empty");string old=metadata.name;metadata.name=name.strip();
            try{store.put_app(metadata);metadata.install_desktop(data_home);}catch(Error e){metadata.name=old;store.put_app(metadata);throw e;}
        }
        public static void uninstall(Store store,WebApp metadata,string data_home,bool remove_data) throws Error {
            var paths=new ProfilePaths(data_home);string profile=paths.webapp_context(metadata.id);int lease=MajorisCef.acquire_profile(profile);
            string desktop=Path.build_filename(data_home,"applications",metadata.desktop_name),hidden=desktop+".uninstalling";bool moved=false;
            try{
                if(FileUtils.test(desktop,FileTest.EXISTS)){File.new_for_path(desktop).move(File.new_for_path(hidden),FileCopyFlags.NONE,null,null);moved=true;}
                if(remove_data)MajorisCef.clear_locked_profile(profile);
                store.delete_app(metadata.id);
                foreach(string size in new string[]{"scalable","256x256"})foreach(string extension in new string[]{".png",".svg"})FileUtils.remove(Path.build_filename(data_home,"icons","hicolor",size,"apps",metadata.application_id+extension));
                FileUtils.remove(hidden);
            }catch(Error e){if(moved && FileUtils.test(hidden,FileTest.EXISTS))FileUtils.rename(hidden,desktop);throw e;}
            finally{MajorisCef.release_profile(lease);}
        }
    }
}
