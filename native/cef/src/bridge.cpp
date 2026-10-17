#include "majoris-cef.h"
#include "profile-data.h"
#include "include/cef_app.h"
#include "include/cef_api_hash.h"
#include "include/cef_client.h"
#include "include/cef_cookie.h"
#include "include/cef_parser.h"
#include "include/cef_task.h"
#include "include/cef_task_manager.h"
#include "include/cef_urlrequest.h"
#include "include/cef_version.h"
#include <atomic>
#include <condition_variable>
#include <cstring>
#include <dlfcn.h>
#include <functional>
#include <map>
#include <mutex>
#include <string>
#include <vector>

namespace {
bool initialized=false;
class Task : public CefTask {
 public:
  explicit Task(std::function<void()> f) : f_(std::move(f)) {}
  void Execute() override { f_(); }
 private:
  std::function<void()> f_;
  IMPLEMENT_REFCOUNTING(Task);
};
void ui(std::function<void()> f) { if(!initialized)return;if(CefCurrentlyOn(TID_UI))f();else CefPostTask(TID_UI, new Task(std::move(f))); }
void gtk(std::function<void()> f) {
  auto *p = new std::function<void()>(std::move(f));
  GSource *source=g_idle_source_new();
  g_source_set_priority(source,G_PRIORITY_DEFAULT);
  g_source_set_callback(source, [](gpointer p)->gboolean {
    (*static_cast<std::function<void()>*>(p))(); return G_SOURCE_REMOVE;
  }, p, [](gpointer p) { delete static_cast<std::function<void()>*>(p); });
  g_source_attach(source,g_main_context_default()); g_source_unref(source);
}
std::mutex lifecycle_mutex;
std::condition_variable lifecycle_cv;
int live = 0;
int profile_lock=-1;
class Client;
std::map<std::string,std::pair<CefRefPtr<CefRequestContext>,int>> private_contexts;
struct State {
  CefRefPtr<Client> client;
};
}
struct _McView { GObject parent_instance; State *state; };
G_DEFINE_TYPE(McView, mc_view, G_TYPE_OBJECT)
static guint signals[3];

namespace {
class Client : public CefClient, public CefLifeSpanHandler, public CefRenderHandler,
 public CefDisplayHandler, public CefLoadHandler, public CefRequestHandler,
 public CefContextMenuHandler, public CefJSDialogHandler, public CefDialogHandler,
 public CefDownloadHandler, public CefPermissionHandler {
 public:
  GWeakRef view;
  CefRefPtr<CefBrowser> browser;
  CefRefPtr<CefRequestContext> context;
  int width=800, height=600;
  float scale=1;
  bool closing=false;
  std::string scope;
  std::string private_key;
  std::string auth_origin;
  gint64 auth_deadline=0;
  static std::string origin(const std::string &url){
    GError *error=nullptr;GUri *u=g_uri_parse(url.c_str(),G_URI_FLAGS_NONE,&error);g_clear_error(&error);
    std::string result;
    if(u && g_strcmp0(g_uri_get_scheme(u),"https")==0 && g_uri_get_host(u) && !g_uri_get_userinfo(u)){
      int port=g_uri_get_port(u);result=std::string("https://")+g_uri_get_host(u)+":"+std::to_string(port<0?443:port);
    }if(u)g_uri_unref(u);return result;
  }
  int token=0;
  std::map<int,std::function<void(bool,std::string)>> replies;
  std::map<uint32_t,CefRefPtr<CefDownloadItemCallback>> downloads;
  CefRefPtr<CefURLRequest> manifest_request;
  std::vector<uint8_t> view_pixels,popup_pixels;
  int pixel_width=0,pixel_height=0,popup_width=0,popup_height=0;
  CefRect popup_rect;
  bool popup_visible=false;
  std::mutex frame_mutex;
  GBytes *pending_frame=nullptr;
  int pending_width=0,pending_height=0;
  bool frame_queued=false;
  Client(McView *v, std::string scope):scope(std::move(scope)) { g_weak_ref_init(&view,v); }
  ~Client() override { if(pending_frame)g_bytes_unref(pending_frame);g_weak_ref_clear(&view); }
  void event(std::string kind, std::string value) {
    CefRefPtr<Client> keep(this);
    gtk([keep,kind=std::move(kind),value=std::move(value)] {
      auto *v = static_cast<McView*>(g_weak_ref_get(&keep->view));
      if (v) { g_signal_emit(v,signals[1],0,kind.c_str(),value.c_str()); g_object_unref(v); }
    });
  }
  void request(std::string kind, std::string origin, std::string message, std::function<void(bool,std::string)> cb) {
    int id=++token;
    replies.emplace(id,std::move(cb));
    CefRefPtr<Client> keep(this);
    gtk([keep,id,kind=std::move(kind),origin=std::move(origin),message=std::move(message)] {
      auto *v=static_cast<McView*>(g_weak_ref_get(&keep->view));
      if (v) { g_signal_emit(v,signals[2],0,id,kind.c_str(),origin.c_str(),message.c_str()); g_object_unref(v); }
      else ui([keep,id] { keep->reply(id,false,""); });
    });
  }
  void reply(int id,bool yes,std::string text) {
    auto it=replies.find(id); if (it==replies.end()) return;
    auto cb=std::move(it->second); replies.erase(it); cb(yes,std::move(text));
  }
  bool in_scope(const std::string &url) {
    if (scope.empty()) return true;
    GError *error=nullptr;
    GUri *u=g_uri_parse(url.c_str(),G_URI_FLAGS_NONE,&error);
    g_clear_error(&error);
    GUri *s=g_uri_parse(scope.c_str(),G_URI_FLAGS_NONE,&error);
    g_clear_error(&error);
    bool ok=false;
    if (u && s && g_uri_get_host(u) && g_uri_get_host(s)) {
      std::string path=g_uri_get_path(u), base=g_uri_get_path(s);
      auto port=[](GUri *v) { int p=g_uri_get_port(v); return p<0 ? (g_strcmp0(g_uri_get_scheme(v),"https")==0 ? 443:80):p; };
      bool boundary=path==base || path.rfind(base+(base.ends_with('/')?"":"/"),0)==0;
      ok=g_strcmp0(g_uri_get_scheme(u),g_uri_get_scheme(s))==0 && g_ascii_strcasecmp(g_uri_get_host(u),g_uri_get_host(s))==0 && port(u)==port(s) && boundary;
    }
    if(u) g_uri_unref(u); if(s) g_uri_unref(s); return ok;
  }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefRenderHandler> GetRenderHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }
  CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() override { return this; }
  CefRefPtr<CefJSDialogHandler> GetJSDialogHandler() override { return this; }
  CefRefPtr<CefDialogHandler> GetDialogHandler() override { return this; }
  CefRefPtr<CefDownloadHandler> GetDownloadHandler() override { return this; }
  CefRefPtr<CefPermissionHandler> GetPermissionHandler() override { return this; }
  void OnAfterCreated(CefRefPtr<CefBrowser> b) override { browser=b; g_message("CEF: view ready");event("ready",""); if(closing) b->GetHost()->CloseBrowser(true); }
  void OnBeforeClose(CefRefPtr<CefBrowser>) override {
    auto pending=std::move(replies); for(auto &[id,cb]:pending) cb(false,"");
    if(!private_key.empty()){auto it=private_contexts.find(private_key);if(it!=private_contexts.end() && --it->second.second==0)private_contexts.erase(it);}
    if(manifest_request){manifest_request->Cancel();manifest_request=nullptr;}
    downloads.clear();browser=nullptr; context=nullptr; event("closed","");
    { std::lock_guard lock(lifecycle_mutex); --live; } lifecycle_cv.notify_all();
  }
  bool OnBeforePopup(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame>,int,const CefString &url,const CefString&,cef_window_open_disposition_t,bool gesture,const CefPopupFeatures&,CefWindowInfo&,CefRefPtr<CefClient>&,CefBrowserSettings&,CefRefPtr<CefDictionaryValue>&,bool*) override {
    if(gesture) event("popup",url.ToString()); return true;
  }
  bool OnBeforeBrowse(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> f,CefRefPtr<CefRequest> r,bool,bool) override {
    if(f->IsMain()){
      auto target=r->GetURL().ToString();
      if(in_scope(target)){auth_origin.clear();auth_deadline=0;return false;}
      if(!auth_origin.empty() && g_get_monotonic_time()<auth_deadline && origin(target)==auth_origin)return false;
      event("external",target);return true;
    }return false;
  }
  bool OnOpenURLFromTab(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame>,const CefString &url,cef_window_open_disposition_t,bool gesture) override {
    if(gesture) event("popup",url.ToString()); return true;
  }
  void GetViewRect(CefRefPtr<CefBrowser>,CefRect &r) override { r=CefRect(0,0,width,height); }
  bool GetScreenInfo(CefRefPtr<CefBrowser>,CefScreenInfo &i) override { i.device_scale_factor=scale; i.rect=CefRect(0,0,width,height); i.available_rect=i.rect; return true; }
  void OnPopupShow(CefRefPtr<CefBrowser> b,bool visible) override {popup_visible=visible;if(!visible){popup_pixels.clear();b->GetHost()->Invalidate(PET_VIEW);}}
  void OnPopupSize(CefRefPtr<CefBrowser>,const CefRect &rect) override {popup_rect=rect;}
  void OnPaint(CefRefPtr<CefBrowser>,PaintElementType type,const RectList&,const void *buffer,int w,int h) override {
    if(closing || w<=0 || h<=0)return;
    const auto *input=static_cast<const uint8_t*>(buffer);
    if(type==PET_VIEW){pixel_width=w;pixel_height=h;view_pixels.assign(input,input+static_cast<size_t>(w)*h*4);}
    else {popup_width=w;popup_height=h;popup_pixels.assign(input,input+static_cast<size_t>(w)*h*4);}
    if(view_pixels.empty())return;
    auto composed=view_pixels;
    if(popup_visible && !popup_pixels.empty()){
      int x=static_cast<int>(popup_rect.x*scale),y=static_cast<int>(popup_rect.y*scale);
      for(int py=0;py<popup_height;py++)for(int px=0;px<popup_width;px++){
        int tx=x+px,ty=y+py;if(tx<0 || ty<0 || tx>=pixel_width || ty>=pixel_height)continue;
        auto *dest=&composed[(ty*pixel_width+tx)*4];auto *src=&popup_pixels[(py*popup_width+px)*4];
        for(int c=0;c<4;c++)dest[c]=static_cast<uint8_t>(std::min(255,src[c]+dest[c]*(255-src[3])/255));
      }
    }
    {
      std::lock_guard lock(frame_mutex);
      if(pending_frame)g_bytes_unref(pending_frame);
      pending_frame=g_bytes_new(composed.data(),composed.size());pending_width=pixel_width;pending_height=pixel_height;
      if(frame_queued)return;frame_queued=true;
    }
    CefRefPtr<Client> keep(this);
    gtk([keep] {
      GBytes *pixels;int w,h;
      {std::lock_guard lock(keep->frame_mutex);pixels=keep->pending_frame;keep->pending_frame=nullptr;w=keep->pending_width;h=keep->pending_height;keep->frame_queued=false;}
      auto *v=static_cast<McView*>(g_weak_ref_get(&keep->view));
      if(v) { g_signal_emit(v,signals[0],0,pixels,w,h); g_object_unref(v); }
      g_bytes_unref(pixels);
    });
  }
  void OnTitleChange(CefRefPtr<CefBrowser>,const CefString &s) override { event("title",s.ToString()); }
  void OnFullscreenModeChange(CefRefPtr<CefBrowser>,bool full) override {event("fullscreen",full?"1":"0");}
  bool OnCursorChange(CefRefPtr<CefBrowser>,CefCursorHandle,cef_cursor_type_t type,const CefCursorInfo&) override {
    event("cursor",type==CT_HAND?"pointer":type==CT_IBEAM?"text":type==CT_WAIT?"wait":type==CT_CROSS?"crosshair":"default");return true;
  }
  void OnAddressChange(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> f,const CefString &s) override { if(f->IsMain()) event("url",s.ToString()); }
  bool OnTooltip(CefRefPtr<CefBrowser>,CefString &s) override { event("tooltip",s.ToString()); return true; }
  void OnLoadingStateChange(CefRefPtr<CefBrowser>,bool loading,bool back,bool forward) override { event("loading",loading?"1":"0"); event("back",back?"1":"0"); event("forward",forward?"1":"0"); }
  void OnLoadError(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> f,ErrorCode code,const CefString &text,const CefString&) override { if(f->IsMain() && code!=ERR_ABORTED) event("error",text.ToString()); }
  void OnRenderProcessTerminated(CefRefPtr<CefBrowser>,TerminationStatus,int,const CefString &s) override { event("crashed",s.ToString()); }
  void OnBeforeContextMenu(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame>,CefRefPtr<CefContextMenuParams> p,CefRefPtr<CefMenuModel> model) override {
    model->Clear(); event("context",p->GetLinkUrl().ToString());
  }
  bool OnJSDialog(CefRefPtr<CefBrowser>,const CefString &origin,JSDialogType type,const CefString &message,const CefString &initial,CefRefPtr<CefJSDialogCallback> cb,bool&) override {
    request(type==JSDIALOGTYPE_PROMPT?"prompt":type==JSDIALOGTYPE_ALERT?"alert":"confirm",origin.ToString(),message.ToString(),[cb](bool yes,std::string text){cb->Continue(yes,text);}); return true;
  }
  bool OnBeforeUnloadDialog(CefRefPtr<CefBrowser>,const CefString &message,bool,CefRefPtr<CefJSDialogCallback> cb) override {
    request("confirm","Leave page?",message.ToString(),[cb](bool yes,std::string text){cb->Continue(yes,text);}); return true;
  }
  bool OnFileDialog(CefRefPtr<CefBrowser>,FileDialogMode mode,const CefString &title,const CefString&,const std::vector<CefString>&,const std::vector<CefString>&,const std::vector<CefString>&,CefRefPtr<CefFileDialogCallback> cb) override {
    request("file",title.ToString(),std::to_string(mode),[cb](bool yes,std::string path){if(yes) cb->Continue({path}); else cb->Cancel();}); return true;
  }
  bool OnBeforeDownload(CefRefPtr<CefBrowser>,CefRefPtr<CefDownloadItem> item,const CefString &name,CefRefPtr<CefBeforeDownloadCallback> cb) override {
    request("download",item->GetURL().ToString(),name.ToString(),[cb](bool yes,std::string path){if(yes) cb->Continue(path,false);}); return true;
  }
  void OnDownloadUpdated(CefRefPtr<CefBrowser>,CefRefPtr<CefDownloadItem> d,CefRefPtr<CefDownloadItemCallback> callback) override {
    if(d->IsInProgress())downloads[d->GetId()]=callback;else downloads.erase(d->GetId());
    event("download",std::to_string(d->GetId())+"\t"+std::to_string(d->GetPercentComplete())+"\t"+(d->IsComplete()?"complete":d->IsCanceled()?"cancelled":"active")+"\t"+d->GetFullPath().ToString());
  }
  bool OnShowPermissionPrompt(CefRefPtr<CefBrowser>,uint64_t,const CefString &origin,uint32_t permissions,CefRefPtr<CefPermissionPromptCallback> cb) override {
    request("permission",origin.ToString(),"Requested permissions: "+std::to_string(permissions),[cb](bool yes,std::string){cb->Continue(yes?CEF_PERMISSION_RESULT_ACCEPT:CEF_PERMISSION_RESULT_DENY);}); return true;
  }
 private:
  IMPLEMENT_REFCOUNTING(Client);
};
class Cookies : public CefCookieVisitor {
 public:
  CefRefPtr<Client> client; std::string result;
  explicit Cookies(CefRefPtr<Client> c):client(c) {}
  ~Cookies() override { client->event("cookies",result); }
  bool Visit(const CefCookie &cookie,int count,int total,bool&) override {
    result+=CefString(&cookie.name).ToString()+"="+CefString(&cookie.value).ToString()+";";
    return true;
  }
 private: IMPLEMENT_REFCOUNTING(Cookies);
};
class CookieSet : public CefSetCookieCallback {
 public: CefRefPtr<Client> client; explicit CookieSet(CefRefPtr<Client> c):client(c) {}
  void OnComplete(bool ok) override { client->event("cookie-set",ok?"1":"0"); }
 private: IMPLEMENT_REFCOUNTING(CookieSet);
};
class Source : public CefStringVisitor {
 public: CefRefPtr<Client> client;explicit Source(CefRefPtr<Client> c):client(c){}
  void Visit(const CefString &html) override {auto text=html.ToString();if(text.size()>4*1024*1024)text.clear();client->event("source",text);}
 private: IMPLEMENT_REFCOUNTING(Source);
};
class Manifest : public CefURLRequestClient {
 public: CefRefPtr<Client> client;std::string body;bool oversized=false;
  explicit Manifest(CefRefPtr<Client> c):client(c){}
  void OnRequestComplete(CefRefPtr<CefURLRequest> request) override {client->event("manifest",!oversized && request->GetRequestStatus()==UR_SUCCESS && request->GetResponse() && request->GetResponse()->GetStatus()==200?body:"");client->manifest_request=nullptr;}
  void OnUploadProgress(CefRefPtr<CefURLRequest>,int64_t,int64_t) override {}
  void OnDownloadProgress(CefRefPtr<CefURLRequest>,int64_t,int64_t) override {}
  void OnDownloadData(CefRefPtr<CefURLRequest> request,const void *data,size_t size) override {if(body.size()+size>512*1024){oversized=true;request->Cancel();}else body.append(static_cast<const char*>(data),size);}
  bool GetAuthCredentials(bool,const CefString&,int,const CefString&,const CefString&,CefRefPtr<CefAuthCallback>) override {return false;}
 private: IMPLEMENT_REFCOUNTING(Manifest);
};
class Deleted : public CefDeleteCookiesCallback {
 public: CefRefPtr<Client> client; explicit Deleted(CefRefPtr<Client> c):client(c) {}
  void OnComplete(int n) override { client->event("cookies-cleared",std::to_string(n)); }
 private: IMPLEMENT_REFCOUNTING(Deleted);
};
class App : public CefApp, public CefBrowserProcessHandler {
 public:
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override {return this;}
  void OnContextInitialized() override {g_message("CEF: browser context ready");}
  void OnBeforeCommandLineProcessing(const CefString&,CefRefPtr<CefCommandLine> command) override {
    command->AppendSwitch("no-first-run");command->AppendSwitch("no-default-browser-check");
    if(g_getenv("MAJORIS_CEF_TEST_HEADLESS")){command->AppendSwitchWithValue("ozone-platform","headless");command->AppendSwitch("disable-gpu");}
  }
 private: IMPLEMENT_REFCOUNTING(App);
};
}

static void mc_view_finalize(GObject *object) {
  auto *v=MC_VIEW(object); mc_view_close(v); delete v->state;
  G_OBJECT_CLASS(mc_view_parent_class)->finalize(object);
}
static void mc_view_class_init(McViewClass *klass) {
  G_OBJECT_CLASS(klass)->finalize=mc_view_finalize;
  signals[0]=g_signal_new("frame",G_TYPE_FROM_CLASS(klass),G_SIGNAL_RUN_LAST,0,nullptr,nullptr,nullptr,G_TYPE_NONE,3,G_TYPE_BYTES,G_TYPE_INT,G_TYPE_INT);
  signals[1]=g_signal_new("event",G_TYPE_FROM_CLASS(klass),G_SIGNAL_RUN_LAST,0,nullptr,nullptr,nullptr,G_TYPE_NONE,2,G_TYPE_STRING,G_TYPE_STRING);
  signals[2]=g_signal_new("request",G_TYPE_FROM_CLASS(klass),G_SIGNAL_RUN_LAST,0,nullptr,nullptr,nullptr,G_TYPE_NONE,4,G_TYPE_INT,G_TYPE_STRING,G_TYPE_STRING,G_TYPE_STRING);
}
static void mc_view_init(McView *v) { v->state=new State; }
gboolean mc_runtime_initialize(const char *root,const char *helper,const char *resources,GError **error) {
  if(initialized) return true;
  Dl_info location{};
  if(dladdr(reinterpret_cast<void*>(cef_api_hash),&location) && location.dli_fname){
    gchar *directory=g_path_get_dirname(location.dli_fname);
    for(const char *name:{"icudtl.dat","resources.pak","chrome_100_percent.pak","v8_context_snapshot.bin"}){
      gchar *file=g_build_filename(directory,name,nullptr);bool exists=g_file_test(file,G_FILE_TEST_IS_REGULAR);g_free(file);
      if(!exists){g_set_error(error,g_quark_from_static_string("majoris-cef"),3,"CEF runtime file %s must be beside libcef.so in %s; run the SDK bootstrap/staging step",name,directory);g_free(directory);return false;}
    }g_free(directory);
  }
  if(!g_file_test(helper,G_FILE_TEST_IS_EXECUTABLE)){g_set_error_literal(error,g_quark_from_static_string("majoris-cef"),4,"CEF subprocess helper is missing or not executable");return false;}
  profile_lock=majoris_profile_acquire(root,error);if(profile_lock<0)return false;
  g_message("CEF: initializing %s",CEF_VERSION);
  cef_api_hash(CEF_API_VERSION,0);
  g_message("CEF: API selected");
  char program[]="majoris-browser";char *argv[]={program,nullptr};
  CefMainArgs args(1,argv); CefSettings settings;
  int process_result=CefExecuteProcess(args,nullptr,nullptr);
  if(process_result>=0){majoris_profile_release(profile_lock);profile_lock=-1;g_set_error_literal(error,g_quark_from_static_string("majoris-cef"),2,"Unexpected subprocess invocation");return false;}
  settings.multi_threaded_message_loop=true;settings.windowless_rendering_enabled=true;
  settings.persist_session_cookies=true;
  CefString(&settings.root_cache_path)=root;
  CefString(&settings.browser_subprocess_path)=helper;
  CefString(&settings.resources_dir_path)=resources;
  CefString(&settings.locales_dir_path)=std::string(resources)+"/locales";
  CefString(&settings.user_agent)="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/" + std::to_string(CHROME_VERSION_MAJOR)+"."+std::to_string(CHROME_VERSION_MINOR)+"."+std::to_string(CHROME_VERSION_BUILD)+"."+std::to_string(CHROME_VERSION_PATCH)+" Safari/537.36 Majoris/" MAJORIS_VERSION;
  g_message("CEF: starting engine");
  initialized=CefInitialize(args,settings,new App,nullptr);
  g_message("CEF: initialization %s",initialized?"complete":"failed");
  if(!initialized){majoris_profile_release(profile_lock);profile_lock=-1;g_set_error_literal(error,g_quark_from_static_string("majoris-cef"),1,"CEF initialization failed; check runtime resources, sandbox and profile lock");}
  return initialized;
}
void mc_runtime_shutdown(void) {
  if(!initialized) return;
  while(true){ {std::lock_guard lock(lifecycle_mutex);if(live==0)break;} g_main_context_iteration(nullptr,true); }
  CefShutdown(); initialized=false;majoris_profile_release(profile_lock);profile_lock=-1;
}
const char *mc_runtime_version(void) { return CEF_VERSION; }
McView *mc_view_new(const char *profile,gboolean ephemeral,const char *url,const char *scope) {
  auto *v=MC_VIEW(g_object_new(MC_TYPE_VIEW,nullptr));
  if(!ephemeral && g_mkdir_with_parents(profile,0700)!=0){g_object_unref(v);return nullptr;}
  CefRefPtr<Client> c=new Client(v,scope); v->state->client=c;
  std::string path=profile, target=url;
  {std::lock_guard lock(lifecycle_mutex); ++live;}
  ui([c,path,target,ephemeral] {
    g_message("CEF: creating view");
    CefRequestContextSettings cs;
    if(!ephemeral) { CefString(&cs.cache_path)=path; cs.persist_session_cookies=true; }
    if(ephemeral){auto &entry=private_contexts[path];if(!entry.first)entry.first=CefRequestContext::CreateContext(cs,nullptr);++entry.second;c->context=entry.first;c->private_key=path;}
    else c->context=CefRequestContext::CreateContext(cs,nullptr);
    CefWindowInfo wi; wi.SetAsWindowless(0); wi.runtime_style=CEF_RUNTIME_STYLE_ALLOY;
    CefBrowserSettings bs; bs.windowless_frame_rate=60;
    if(!CefBrowserHost::CreateBrowser(wi,c,target,bs,nullptr,c->context)) {
      c->event("error","CEF browser creation failed");
      if(!c->private_key.empty()){auto it=private_contexts.find(c->private_key);if(it!=private_contexts.end() && --it->second.second==0)private_contexts.erase(it);}c->context=nullptr;
      {std::lock_guard lock(lifecycle_mutex); --live;} lifecycle_cv.notify_all();
    }
  });
  return v;
}
void mc_view_close(McView *v) { auto c=v->state->client; if(c) ui([c]{c->closing=true; if(c->browser) c->browser->GetHost()->CloseBrowser(true);}); }
void mc_view_load(McView *v,const char *url) { auto c=v->state->client; std::string s=url; ui([c,s]{if(c->browser)c->browser->GetMainFrame()->LoadURL(s);}); }
void mc_view_resize(McView *v,int w,int h,double s) { auto c=v->state->client; ui([c,w,h,s]{c->width=std::max(1,w); c->height=std::max(1,h); c->scale=s; if(c->browser){c->browser->GetHost()->NotifyScreenInfoChanged(); c->browser->GetHost()->WasResized();}}); }
void mc_view_focus(McView *v,gboolean focus) { auto c=v->state->client; ui([c,focus]{if(c->browser)c->browser->GetHost()->SetFocus(focus);}); }
void mc_view_reply(McView *v,int token,gboolean yes,const char *text) {auto c=v->state->client; std::string s=text; ui([c,token,yes,s]{c->reply(token,yes,s);});}
void mc_view_pointer(McView *v,int kind,int x,int y,int button,int modifiers,int dx,int dy) {
  auto c=v->state->client; ui([=]{if(!c->browser)return; CefMouseEvent e; e.x=x;e.y=y;e.modifiers=modifiers;
    auto h=c->browser->GetHost();
    if(kind==0)h->SendMouseMoveEvent(e,false);
    else if(kind==3)h->SendMouseWheelEvent(e,dx,dy);
    else h->SendMouseClickEvent(e,button==3?MBT_RIGHT:button==2?MBT_MIDDLE:MBT_LEFT,kind==2,1);
  });
}
void mc_view_key(McView *v,int kind,int key,int hardware,int modifiers) {
  auto c=v->state->client; ui([=]{if(!c->browser)return; CefKeyEvent e; e.type=kind==0?KEYEVENT_RAWKEYDOWN:KEYEVENT_KEYUP; e.windows_key_code=key;e.native_key_code=hardware;e.modifiers=modifiers;c->browser->GetHost()->SendKeyEvent(e);});
}
void mc_view_text(McView *v,const char *text) {
  auto c=v->state->client; std::string s=text;
  ui([c,s]{if(!c->browser)return; CefString utf16=s; for(size_t i=0;i<utf16.length();++i){CefKeyEvent e;e.type=KEYEVENT_CHAR;e.character=utf16.c_str()[i];e.unmodified_character=e.character;c->browser->GetHost()->SendKeyEvent(e);}});
}
void mc_view_command(McView *v,const char *command) {
  auto c=v->state->client; std::string s=command;
  ui([c,s]{if(!c->browser)return; auto b=c->browser;auto h=b->GetHost();auto f=b->GetMainFrame();
    if(s=="back")b->GoBack(); else if(s=="forward")b->GoForward(); else if(s=="reload")b->Reload(); else if(s=="hard-reload")b->ReloadIgnoreCache(); else if(s=="stop")b->StopLoad();
    else if(s=="zoom-in")h->SetZoomLevel(h->GetZoomLevel()+0.5);else if(s=="zoom-out")h->SetZoomLevel(h->GetZoomLevel()-0.5);else if(s=="zoom-reset")h->SetZoomLevel(0);
    else if(s=="print")h->Print();else if(s=="copy")f->Copy();else if(s=="cut")f->Cut();else if(s=="paste")f->Paste();else if(s=="select-all")f->SelectAll();else if(s=="source")f->ViewSource();
    else if(s=="mute")h->SetAudioMuted(!h->IsAudioMuted());
    else if(s=="devtools"){CefWindowInfo wi;wi.runtime_style=CEF_RUNTIME_STYLE_ALLOY;CefBrowserSettings bs;h->ShowDevTools(wi,nullptr,bs,CefPoint());}
    else if(s.rfind("find:",0)==0)h->Find(s.substr(5),true,false,false);
    else if(s=="find-stop")h->StopFinding(true);
    else if(s=="source-metadata")f->GetSource(new Source(c));
    else if(s.rfind("download-",0)==0){auto colon=s.find(':');if(colon!=std::string::npos){auto id=static_cast<uint32_t>(g_ascii_strtoull(s.c_str()+colon+1,nullptr,10));auto it=c->downloads.find(id);if(it!=c->downloads.end()){if(s.starts_with("download-cancel:"))it->second->Cancel();else if(s.starts_with("download-pause:"))it->second->Pause();else if(s.starts_with("download-resume:"))it->second->Resume();}}}
    else if(s=="tasks"){
      auto manager=CefTaskManager::GetTaskManager();CefTaskManager::TaskIdList ids;std::string data;
      if(manager && manager->GetTaskIdsList(ids))for(auto id:ids){CefTaskInfo info;if(manager->GetTaskInfo(id,info)){
        gchar *title=g_strescape(CefString(&info.title).ToString().c_str(),nullptr);
        data+=std::to_string(id)+"\t"+std::to_string(info.type)+"\t"+std::to_string(info.cpu_usage)+"\t"+std::to_string(info.memory)+"\t"+std::to_string(info.is_killable)+"\t"+title+"\n";g_free(title);
      }}c->event("tasks",data);
    }else if(s.rfind("kill-task:",0)==0){auto manager=CefTaskManager::GetTaskManager();if(manager)manager->KillTask(g_ascii_strtoll(s.c_str()+10,nullptr,10));}
  });
}
void mc_view_clear_cookies(McView *v) {auto c=v->state->client;ui([c]{if(c->context)c->context->GetCookieManager(nullptr)->DeleteCookies("","",new Deleted(c));});}
void mc_view_set_cookie(McView *v,const char *url,const char *name,const char *value) {
  auto c=v->state->client;std::string u=url,n=name,s=value;
  ui([c,u,n,s]{if(!c->context)return;CefCookie cookie;CefString(&cookie.name)=n;CefString(&cookie.value)=s;CefString(&cookie.path)="/";c->context->GetCookieManager(nullptr)->SetCookie(u,cookie,new CookieSet(c));});
}
void mc_view_get_cookies(McView *v,const char *url) {auto c=v->state->client;std::string u=url;ui([c,u]{if(c->context)c->context->GetCookieManager(nullptr)->VisitUrlCookies(u,true,new Cookies(c));});}
void mc_view_allow_auth(McView *v,const char *url){auto c=v->state->client;std::string target=url;ui([c,target]{if(c->scope.empty())return;c->auth_origin=Client::origin(target);c->auth_deadline=g_get_monotonic_time()+120*G_USEC_PER_SEC;});}
void mc_view_autofill(McView *v,const char *origin,const char *username,const char *password){
  auto c=v->state->client;std::string site=origin,user=username,secret=password;
  ui([c,site,user,secret]{
    if(!c->browser || Client::origin(site).empty())return;
    auto frame=c->browser->GetMainFrame();
    if(Client::origin(frame->GetURL().ToString())!=Client::origin(site))return;
    auto data=CefDictionaryValue::Create();data->SetString("username",user);data->SetString("password",secret);
    auto value=CefValue::Create();value->SetDictionary(data);
    std::string script="(()=>{const v="+CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString()+";const put=(selector,text)=>{const e=document.querySelector(selector);if(!e||e.disabled||e.readOnly||!e.getClientRects().length)return;Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(e,text);e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));};put('input[autocomplete=username],input[type=email],input[name=username]',v.username);put('input[type=password]',v.password);})();";
    frame->ExecuteJavaScript(script,frame->GetURL(),0);
  });
}
void mc_view_fetch_manifest(McView *v,const char *url){auto c=v->state->client;std::string target=url;ui([c,target]{
  if(!c->context)return;
  GError *error=nullptr;GUri *uri=g_uri_parse(target.c_str(),G_URI_FLAGS_NONE,&error);g_clear_error(&error);
  bool valid=uri && g_uri_get_host(uri) && !g_uri_get_userinfo(uri) && (g_strcmp0(g_uri_get_scheme(uri),"https")==0 || g_strcmp0(g_uri_get_scheme(uri),"http")==0);if(uri)g_uri_unref(uri);
  if(!valid){c->event("manifest","");return;}
  auto request=CefRequest::Create();request->SetURL(target);request->SetMethod("GET");c->manifest_request=CefURLRequest::Create(request,new Manifest(c),c->context);
});}
