#include "profile-data.h"
#include "majoris-cef.h"
#include <gio/gio.h>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#include <cerrno>
#include <string>

int majoris_profile_acquire(const char *path,GError **error){
  gchar *parent=g_path_get_dirname(path);
  if(g_mkdir_with_parents(parent,0700)!=0){g_free(parent);g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_FAILED,"Cannot create profile parent directory");return -1;}g_free(parent);
  std::string lock=std::string(path)+".lock";
  int fd=open(lock.c_str(),O_CREAT|O_RDWR|O_CLOEXEC|O_NOFOLLOW,0600);
  if(fd<0 || flock(fd,LOCK_EX|LOCK_NB)!=0){
    if(fd>=0)close(fd);
    g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_BUSY,"The profile is in use; close its application before clearing data");return -1;
  }return fd;
}
void majoris_profile_release(int fd){if(fd>=0){flock(fd,LOCK_UN);close(fd);}}

static gboolean remove_tree(GFile *file,GError **error){
  auto type=g_file_query_file_type(file,G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,nullptr);
  if(type==G_FILE_TYPE_DIRECTORY){
    GFileEnumerator *items=g_file_enumerate_children(file,G_FILE_ATTRIBUTE_STANDARD_NAME,G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,nullptr,error);
    if(!items)return false;
    while(true){
      GFileInfo *info=g_file_enumerator_next_file(items,nullptr,error);
      if(!info)break;
      GFile *child=g_file_get_child(file,g_file_info_get_name(info));g_object_unref(info);
      bool ok=remove_tree(child,error);g_object_unref(child);
      if(!ok){g_object_unref(items);return false;}
    }
    g_object_unref(items);if(error && *error)return false;
  }
  if(!g_file_query_exists(file,nullptr) && type!=G_FILE_TYPE_SYMBOLIC_LINK)return true;
  return g_file_delete(file,nullptr,error);
}
gboolean mc_profile_clear(const char *path,GError **error){
  if(!g_path_is_absolute(path) || g_file_test(path,G_FILE_TEST_IS_SYMLINK)){
    g_set_error_literal(error,G_IO_ERROR,G_IO_ERROR_INVALID_ARGUMENT,"Refusing an invalid or symlinked profile root");return false;
  }
  int fd=majoris_profile_acquire(path,error);if(fd<0)return false;
  GFile *file=g_file_new_for_path(path);bool result=remove_tree(file,error);g_object_unref(file);
  majoris_profile_release(fd);return result;
}
