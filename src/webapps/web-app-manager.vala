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
        private static void checked_parent(string path) throws Error {
            File? directory=File.new_for_path(path).get_parent();
            while(directory!=null){
                try{var info=directory.query_info(FileAttribute.STANDARD_TYPE,FileQueryInfoFlags.NOFOLLOW_SYMLINKS);if(info.get_file_type()!=FileType.DIRECTORY)throw new IOError.INVALID_ARGUMENT("Refusing a symlinked integration directory");}catch(IOError.NOT_FOUND e){}
                directory=directory.get_parent();
            }
        }
        private static string[] integration_files(WebApp metadata,string data_home){
            string[] result={Path.build_filename(data_home,"applications",metadata.desktop_name)};
            foreach(string size in new string[]{"scalable","256x256"})foreach(string extension in new string[]{".png",".svg"})result+=Path.build_filename(data_home,"icons","hicolor",size,"apps",metadata.application_id+extension);
            return result;
        }
        private static bool integration_exists(File file) throws Error {
            try{file.query_info(FileAttribute.STANDARD_TYPE,FileQueryInfoFlags.NOFOLLOW_SYMLINKS);return true;}catch(IOError.NOT_FOUND e){return false;}
        }
        public static void uninstall(Store store,WebApp metadata,string data_home,bool remove_data,ShellIntegration? integration=null) throws Error {
            var paths=new ProfilePaths(data_home);string profile=paths.webapp_context(metadata.id);int lease=MajorisCef.acquire_profile(profile);
            var moved=new Gee.ArrayList<string>();var shell=integration??new DesktopShellIntegration();bool pinned=false,committed=false;
            try{
                committed=store.uninstall_pending(metadata.id);
                string[] files=integration_files(metadata,data_home);foreach(string path in files)checked_parent(path);
                if(committed){foreach(var job in store.pending_uninstalls())if(job.url==metadata.id)remove_data=job.id==1;}
                else{
                    pinned=shell.is_pinned(metadata.desktop_name);
                    foreach(string path in files){
                        var original=File.new_for_path(path);var hidden=File.new_for_path(path+".uninstalling");
                        // Recover a previously interrupted pre-commit rename.
                        if(integration_exists(hidden) && !integration_exists(original))hidden.move(original,FileCopyFlags.NOFOLLOW_SYMLINKS,null,null);
                        if(integration_exists(original)){
                            if(original.query_info(FileAttribute.STANDARD_TYPE,FileQueryInfoFlags.NOFOLLOW_SYMLINKS).get_file_type()!=FileType.REGULAR)throw new IOError.INVALID_ARGUMENT("Refusing a non-regular application integration file");
                            original.move(hidden,FileCopyFlags.NOFOLLOW_SYMLINKS,null,null);moved.add(path);
                        }
                    }
                    if(pinned && !shell.set_pinned(metadata.desktop_name,false))throw new IOError.FAILED("Cannot remove application dock pin");
                    store.begin_uninstall(metadata,remove_data);committed=true;
                }
                // Unregistration is durable. Failures here retain a retry job;
                // profile erasure is last, after all integration cleanup succeeds.
                foreach(string path in files){var hidden=File.new_for_path(path+".uninstalling");try{hidden.delete();}catch(IOError.NOT_FOUND e){}}
                if(remove_data)MajorisCef.clear_locked_profile(profile);
                store.finish_uninstall(metadata.id);
            }catch(Error e){
                if(!committed){string rollback="";foreach(string path in moved){try{var hidden=File.new_for_path(path+".uninstalling");if(integration_exists(hidden))hidden.move(File.new_for_path(path),FileCopyFlags.NOFOLLOW_SYMLINKS,null,null);}catch(Error restore){rollback+="\n"+restore.message;}}if(pinned && !shell.set_pinned(metadata.desktop_name,true))rollback+="\nDock pin could not be restored";if(rollback!="")throw new IOError.FAILED("Uninstall aborted: "+e.message+". Some integration files require recovery:"+rollback);}
                throw e;
            }
            finally{MajorisCef.release_profile(lease);}
        }
    }
}
