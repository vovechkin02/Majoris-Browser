#include "profile-data.h"
#include "majoris-cef.h"
#include <gio/gio.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <cerrno>
#include <string>
#include <array>
#include <charconv>

static bool parse_version(std::string text,std::array<unsigned,4>& parts){
  while(!text.empty() && (text.back()=='\n' || text.back()=='\r'))text.pop_back();
  size_t start=0;
  for(size_t i=0;i<4;i++){
    size_t end=text.find('.',start);if((i<3 && end==std::string::npos) || (i==3 && end!=std::string::npos))return false;
    if(end==std::string::npos)end=text.size();
    auto result=std::from_chars(text.data()+start,text.data()+end,parts[i]);
    if(result.ec!=std::errc() || result.ptr!=text.data()+end)return false;start=end+1;
  }return true;
}
bool majoris_profile_version(const char *path,const char *version,GError **error){
  std::array<unsigned,4> current{},previous{};
  if(!parse_version(version,current)){g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_INVALID_DATA,"Invalid runtime version");return false;}
  if(g_mkdir_with_parents(path,0700)!=0){g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_FAILED,"Cannot create runtime profile");return false;}
  int directory=open(path,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
  if(directory<0){g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_FAILED,"Cannot safely open runtime profile");return false;}
  bool ok=true;std::string last;
  // Chromium's own marker also protects profiles predating Majoris's guard.
  for(const char* marker:{"majoris-engine-version","Last Version"}){
    int input=openat(directory,marker,O_RDONLY|O_NOFOLLOW|O_CLOEXEC|O_NONBLOCK);
    if(input<0){if(errno!=ENOENT)ok=false;continue;}
    struct stat st{};char buffer[129];ssize_t count=-1;
    if(fstat(input,&st)==0 && S_ISREG(st.st_mode))count=read(input,buffer,sizeof(buffer));close(input);
    if(count<=0 || count>128 || !parse_version(std::string(buffer,count),previous) || previous>current){ok=false;break;}
  }
  if(ok){
    int output=openat(directory,".majoris-engine-version.tmp",O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0600);
    // A crash can leave our own temporary marker; never follow it.
    if(output<0 && errno==EEXIST){unlinkat(directory,".majoris-engine-version.tmp",0);output=openat(directory,".majoris-engine-version.tmp",O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0600);}
    std::string data=std::string(version)+"\n";
    ok=output>=0 && write(output,data.data(),data.size())==static_cast<ssize_t>(data.size()) && fsync(output)==0;
    if(output>=0)close(output);
    if(ok)ok=renameat(directory,".majoris-engine-version.tmp",directory,"majoris-engine-version")==0 && fsync(directory)==0;
  }
  close(directory);
  if(!ok)g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_FAILED,"Profile version is newer, invalid or inaccessible. Use a compatible runtime; no profile data was reset.");
  return ok;
}

// Hold real parent directories rather than resolving a mutable pathname again
// during deletion. Neither parent traversal nor recursion follows symlinks.
static int checked_parent(const char *path,GError **error){
  gchar *base=g_path_get_basename(path);
  bool invalid_base=!*base || std::string(base)=="/" || std::string(base)=="." || std::string(base)=="..";g_free(base);
  if(!g_path_is_absolute(path) || invalid_base){
    g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_INVALID_ARGUMENT,"Invalid profile root");return -1;
  }
  gchar *parent=g_path_get_dirname(path);gchar **parts=g_strsplit(parent,"/",-1);g_free(parent);
  int descriptor=open("/",O_RDONLY|O_DIRECTORY|O_CLOEXEC);
  for(size_t i=0;parts[i] && descriptor>=0;i++){
    if(!*parts[i] || std::string(parts[i])==".")continue;
    if(std::string(parts[i])==".."){close(descriptor);descriptor=-1;errno=EINVAL;break;}
    int next=openat(descriptor,parts[i],O_RDONLY|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW);int saved=errno;close(descriptor);descriptor=next;errno=saved;
  }
  g_strfreev(parts);
  if(descriptor<0)g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_INVALID_ARGUMENT,"Refusing a symlinked or inaccessible profile parent");
  return descriptor;
}
int majoris_profile_acquire(const char *path,GError **error){
  if(!g_path_is_absolute(path) || std::string(path)=="/"){g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_INVALID_ARGUMENT,"Invalid profile root");return -1;}
  gchar *parent=g_path_get_dirname(path);
  if(g_mkdir_with_parents(parent,0700)!=0){g_free(parent);g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_FAILED,"Cannot create profile parent directory");return -1;}g_free(parent);
  int directory=checked_parent(path,error);if(directory<0)return -1;
  gchar *base=g_path_get_basename(path);std::string lock=std::string(base)+".lock";g_free(base);
  int descriptor=openat(directory,lock.c_str(),O_CREAT|O_RDWR|O_CLOEXEC|O_NOFOLLOW,0600);close(directory);
  if(descriptor<0 || flock(descriptor,LOCK_EX|LOCK_NB)!=0){if(descriptor>=0)close(descriptor);g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_BUSY,"The profile is in use; close its application before clearing data");return -1;}
  return descriptor;
}
void majoris_profile_release(int descriptor){if(descriptor>=0){flock(descriptor,LOCK_UN);close(descriptor);}}
static gboolean failure(GError **error,const char *message){g_set_error(error,G_IO_ERROR,g_io_error_from_errno(errno),"%s: %s",message,g_strerror(errno));return false;}
static gboolean remove_at(int parent,const char *name,int depth,GError **error){
  if(depth>128){g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_FAILED,"Profile directory nesting exceeds the clearing limit");return false;}
  struct stat info;if(fstatat(parent,name,&info,AT_SYMLINK_NOFOLLOW)!=0){if(errno==ENOENT)return true;return failure(error,"Cannot inspect profile entry");}
  if(!S_ISDIR(info.st_mode)){if(unlinkat(parent,name,0)!=0 && errno!=ENOENT)return failure(error,"Cannot remove profile entry");return true;}
  int descriptor=openat(parent,name,O_RDONLY|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW);if(descriptor<0)return failure(error,"Cannot open profile directory");
  DIR *directory=fdopendir(descriptor);if(!directory){close(descriptor);return failure(error,"Cannot enumerate profile directory");}
  bool result=true;struct dirent *entry;
  while(true){errno=0;entry=readdir(directory);if(!entry){if(errno)result=failure(error,"Cannot enumerate profile directory");break;}if(std::string(entry->d_name)=="." || std::string(entry->d_name)=="..")continue;if(!remove_at(descriptor,entry->d_name,depth+1,error)){result=false;break;}}
  closedir(directory);if(!result)return false;
  if(unlinkat(parent,name,AT_REMOVEDIR)!=0 && errno!=ENOENT)return failure(error,"Cannot remove profile directory");return true;
}
gboolean mc_profile_clear_locked(const char *path,GError **error){
  int parent=checked_parent(path,error);if(parent<0)return false;gchar *base=g_path_get_basename(path);struct stat info;
  if(fstatat(parent,base,&info,AT_SYMLINK_NOFOLLOW)==0 && S_ISLNK(info.st_mode)){g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_INVALID_ARGUMENT,"Refusing a symlinked profile root");g_free(base);close(parent);return false;}
  bool result=remove_at(parent,base,0,error);g_free(base);close(parent);return result;
}
gboolean mc_profile_clear(const char *path,GError **error){
  int descriptor=majoris_profile_acquire(path,error);if(descriptor<0)return false;bool result=mc_profile_clear_locked(path,error);majoris_profile_release(descriptor);return result;
}
int mc_profile_acquire(const char *path,GError **error){return majoris_profile_acquire(path,error);}
void mc_profile_release(int descriptor){majoris_profile_release(descriptor);}
