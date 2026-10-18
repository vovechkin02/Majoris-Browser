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
#include "include/cef_devtools_message_observer.h"
#include "include/cef_version.h"
#include "include/cef_version_info.h"
#include "include/cef_pack_strings.h"
#include "include/cef_stream.h"
#include "auth-flow.h"
#include "credential-observer.h"
#include "site-cookies.h"
#include <atomic>
#include <algorithm>
#include <condition_variable>
#include <cmath>
#include <cstring>
#include <dlfcn.h>
#include <functional>
#include <map>
#include <set>
#include <mutex>
#include <string>
#include <vector>
#include <glib/gstdio.h>

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
std::string chrome_version(){return std::to_string(cef_version_info(4))+"."+std::to_string(cef_version_info(5))+"."+std::to_string(cef_version_info(6))+"."+std::to_string(cef_version_info(7));}
std::string user_agent(){return "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"+chrome_version()+" Safari/537.36 Majoris/" MAJORIS_VERSION;}
int profile_lock=-1;
class Client;
CefRefPtr<CefDownloadImageCallback> image_callback(CefRefPtr<Client> client,std::string tag);
std::map<std::string,std::pair<CefRefPtr<CefRequestContext>,int>> private_contexts;
struct State {
  CefRefPtr<Client> client;
  std::atomic<bool> auth_popup=false;
};
}
struct _McView { GObject parent_instance; State *state; };
G_DEFINE_TYPE(McView, mc_view, G_TYPE_OBJECT)
static guint signals[4];

namespace {
class DragBytes : public CefWriteHandler {
 public:
  std::vector<uint8_t> bytes;size_t offset=0;static constexpr size_t limit=32*1024*1024;
  size_t Write(const void *data,size_t size,size_t count) override {if(!size || count>(limit-offset)/size)return 0;size_t length=size*count;bytes.resize(std::max(bytes.size(),offset+length));memcpy(bytes.data()+offset,data,length);offset+=length;return count;}
  int Seek(int64_t value,int whence) override {int64_t target=value+(whence==SEEK_CUR?offset:whence==SEEK_END?bytes.size():0);if(target<0 || target>static_cast<int64_t>(limit))return -1;offset=target;return 0;}
  int64_t Tell() override {return offset;}
  int Flush() override {return 0;}
  bool MayBlock() override {return false;}
 private: IMPLEMENT_REFCOUNTING(DragBytes);
};
class Client : public CefClient, public CefLifeSpanHandler, public CefRenderHandler,
 public CefDisplayHandler, public CefLoadHandler, public CefRequestHandler,
 public CefContextMenuHandler, public CefJSDialogHandler, public CefDialogHandler,
 public CefDownloadHandler, public CefPermissionHandler, public CefDevToolsMessageObserver, public CefPrintHandler, public CefFocusHandler, public CefAccessibilityHandler, public CefResourceRequestHandler {
 public:
  GWeakRef view;
  CefRefPtr<CefBrowser> browser;
  CefRefPtr<CefRequestContext> context;
  int width=800, height=600;
  float scale=1;
  bool closing=false;
  std::atomic<bool> threat_checks=false;
  CefRefPtr<CefResourceRequestHandler> GetResourceRequestHandler(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> frame,CefRefPtr<CefRequest>,bool navigation,bool,const CefString&,bool&) override {return threat_checks && navigation && frame && frame->IsMain()?this:nullptr;}
  ReturnValue OnBeforeResourceLoad(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame>,CefRefPtr<CefRequest> resource,CefRefPtr<CefCallback> callback) override {
    std::string url=resource->GetURL();CefURLParts parts;if(!CefParseURL(url,parts) || (CefString(&parts.scheme)!="https" && CefString(&parts.scheme)!="http"))return RV_CONTINUE;
    CefRefPtr<Client> keep=this;ui([keep,url,callback]{if(keep->closing){callback->Cancel();return;}int token=keep->request("threat-check",url,"",[callback](bool allowed,std::string){if(allowed)callback->Continue();else callback->Cancel();});CefPostDelayedTask(TID_UI,new Task([keep,token]{keep->reply(token,false,"");}),5000);});return RV_CONTINUE_ASYNC;
  }
  bool close_requested=false;
  bool source_drag_active=false;
  bool accessibility_enabled=false;
  CefRefPtr<CefAccessibilityHandler> GetAccessibilityHandler() override {return this;}
  void OnAccessibilityTreeChange(CefRefPtr<CefValue> value) override {if(!accessibility_enabled || closing)return;auto text=CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString();if(text.size()<=4*1024*1024)event("accessibility-tree",text);else event("accessibility-error","Accessibility update exceeds the safety limit");}
  void OnAccessibilityLocationChange(CefRefPtr<CefValue> value) override {if(!accessibility_enabled || closing)return;auto text=CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString();if(text.size()<=2*1024*1024)event("accessibility-location",text);}
  bool target_drag_active=false;
  DragOperation target_drag_operation=DRAG_OPERATION_NONE;
  void UpdateDragCursor(CefRefPtr<CefBrowser>,DragOperation operation) override {target_drag_operation=operation;if(target_drag_active)event("drag-target-cursor",std::to_string(operation));}
  int context_x=0,context_y=0;uint64_t context_generation=0;
  std::string context_source;
  void context_media(std::string action){
    if(action=="pip"){event("operation-error","picture-in-picture");return;}if(action!="play" && action!="pause" && action!="mute" && action!="unmute")return;
    auto args=CefDictionaryValue::Create();args->SetInt("x",context_x);args->SetInt("y",context_y);args->SetBool("includeUserAgentShadowDOM",true);
    protocol("DOM.getNodeForLocation",args,"context-hit:"+action+"|"+std::to_string(context_generation));
  }
  void end_drag(int x,int y,int operation){
    if(!source_drag_active)return;source_drag_active=false;
    if(browser){browser->GetHost()->DragSourceEndedAt(x,y,static_cast<cef_drag_operations_mask_t>(operation));browser->GetHost()->DragSourceSystemDragEnded();}
    event("drag-ended","");
  }
  bool StartDragging(CefRefPtr<CefBrowser>,CefRefPtr<CefDragData> data,DragOperationsMask operations,int x,int y) override {
    if(closing || source_drag_active)return false;
    auto payload=CefDictionaryValue::Create();
    for(auto &[key,value]:std::map<std::string,std::string>{{"text",data->GetFragmentText()},{"html",data->GetFragmentHtml()},{"link",data->GetLinkURL()},{"name",data->GetFileName()}}){if(value.size()>8*1024*1024)return false;payload->SetString(key,value);}
    size_t length=data->GetFileContents(nullptr);
    if(length>DragBytes::limit)return false;
    if(length){auto bytes=CefRefPtr<DragBytes>(new DragBytes());if(data->GetFileContents(CefStreamWriter::CreateForHandler(bytes))!=length || bytes->bytes.size()!=length)return false;gchar *encoded=g_base64_encode(bytes->bytes.data(),bytes->bytes.size());payload->SetString("file",encoded);g_free(encoded);}
    auto image=data->GetImage();if(image && image->GetWidth()<=512 && image->GetHeight()<=512){int w,h;auto png=image->GetAsPNG(1,true,w,h);if(png && png->GetSize()<=2*1024*1024){std::vector<uint8_t> bytes(png->GetSize());png->GetData(bytes.data(),bytes.size(),0);gchar *encoded=g_base64_encode(bytes.data(),bytes.size());payload->SetString("icon",encoded);g_free(encoded);}}
    auto hotspot=data->GetImageHotspot();payload->SetInt("hotX",hotspot.x);payload->SetInt("hotY",hotspot.y);payload->SetInt("operations",operations);payload->SetInt("x",x);payload->SetInt("y",y);
    auto value=CefValue::Create();value->SetDictionary(payload);source_drag_active=true;event("drag-start",CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString());return true;
  }
  std::string scope;
  std::string private_key;
  std::shared_ptr<AuthFlow> auth_flow;
  std::string pending_auth_redirect;
  void revoke_auth(std::string reason){if(auth_flow){auth_flow->active=false;auth_flow->origins.clear();}pending_auth_redirect.clear();event("auth-ended",reason);}
  void allow_auth(const std::string &target,int seconds=120){
    if(scope.empty() || origin(target).empty())return;
    if(auth_flow && auth_flow->alive() && pending_auth_redirect==target){auth_flow->origins.insert(AuthFlow::origin(target));pending_auth_redirect.clear();return;}
    std::string back,state;if(!AuthFlow::candidate(target,[this](auto &url){return in_scope(url);},back,state))return;
    if(!auth_flow || auth_flow->active || auth_flow->return_uri!=back || auth_flow->state!=state){revoke_auth("replaced");auth_flow=std::make_shared<AuthFlow>();auth_flow->initiator=AuthFlow::origin(scope);}
    auth_flow->return_uri=back;auth_flow->state=state;auth_flow->origins.insert(AuthFlow::origin(target));auth_flow->deadline=g_get_monotonic_time()+std::clamp(seconds,1,120)*G_USEC_PER_SEC;auth_flow->active=true;auto transaction=auth_flow;CefPostDelayedTask(TID_UI,new Task([transaction]{if(!transaction->alive()){transaction->active=false;transaction->origins.clear();}}),std::clamp(seconds,1,120)*1000);event("auth-started",auth_flow->id);
  }
  static std::string origin(const std::string &url){
    GError *error=nullptr;GUri *u=g_uri_parse(url.c_str(),G_URI_FLAGS_NONE,&error);g_clear_error(&error);
    std::string result;
    if(u && g_strcmp0(g_uri_get_scheme(u),"https")==0 && g_uri_get_host(u) && !g_uri_get_userinfo(u)){
      int port=g_uri_get_port(u);result=std::string("https://")+g_uri_get_host(u)+":"+std::to_string(port<0?443:port);
    }if(u)g_uri_unref(u);return result;
  }
  int token=0;
  std::map<int,std::function<void(bool,std::string)>> replies;
  std::map<int,std::string> reply_kinds;
  std::map<uint64_t,int> permission_prompts;
  std::map<int,CefRefPtr<Client>> popup_children;
  CefRefPtr<Client> opener;
  int popup_id=0;
  std::map<std::string,std::map<std::string,int>> permission_policy;
  std::set<std::string> permission_origins;
  std::set<std::string> temporary_permission_origins;
  static const std::map<std::string,cef_content_setting_types_t>& permission_types(){
    static const std::map<std::string,cef_content_setting_types_t> types={{"camera",CEF_CONTENT_SETTING_TYPE_MEDIASTREAM_CAMERA},{"microphone",CEF_CONTENT_SETTING_TYPE_MEDIASTREAM_MIC},{"location",CEF_CONTENT_SETTING_TYPE_GEOLOCATION},{"notifications",CEF_CONTENT_SETTING_TYPE_NOTIFICATIONS},{"clipboard",CEF_CONTENT_SETTING_TYPE_CLIPBOARD_READ_WRITE},{"multiple downloads",CEF_CONTENT_SETTING_TYPE_AUTOMATIC_DOWNLOADS},{"pointer lock",CEF_CONTENT_SETTING_TYPE_POINTER_LOCK},{"keyboard lock",CEF_CONTENT_SETTING_TYPE_KEYBOARD_LOCK},{"storage access",CEF_CONTENT_SETTING_TYPE_STORAGE_ACCESS},{"local fonts",CEF_CONTENT_SETTING_TYPE_LOCAL_FONTS},{"popups",CEF_CONTENT_SETTING_TYPE_POPUPS}};return types;
  }
  void apply_permissions(const std::string &site){
    if(!context || site.empty())return;permission_origins.insert(site);
    for(auto &[kind,type]:permission_types()){int value=permission_policy[site][kind];context->SetContentSetting(site,site,type,value==1?CEF_CONTENT_SETTING_VALUE_ALLOW:value==2?CEF_CONTENT_SETTING_VALUE_BLOCK:CEF_CONTENT_SETTING_VALUE_DEFAULT);}
  }
  void set_permissions(const std::string &text){
    auto data=CefParseJSON(text,JSON_PARSER_RFC);if(!data || data->GetType()!=VTYPE_LIST)return;permission_policy.clear();auto rows=data->GetList();
    for(size_t i=0;i<rows->GetSize() && i<10000;i++){auto row=rows->GetDictionary(i);if(!row)continue;auto site=row->GetString("origin").ToString(),kind=row->GetString("kind").ToString();int value=row->GetInt("value");CefURLParts parts;if(!CefParseURL(site,parts) || (CefString(&parts.scheme)!="https" && CefString(&parts.scheme)!="http") || !permission_types().contains(kind) || value<0 || value>2)continue;site=CefString(&parts.origin);permission_policy[site][kind]=value;permission_origins.insert(site);}
    auto origins=permission_origins;for(auto &site:origins)apply_permissions(site);
  }
  std::map<uint32_t,CefRefPtr<CefDownloadItemCallback>> downloads;
  CefRefPtr<CefURLRequest> manifest_request;
  CefRefPtr<CefRegistration> devtools_registration;
  int protocol_id=1000;
  std::map<std::string,bool> media_players;
  std::set<std::string> audio_players;
  std::map<std::string,bool> audio_contexts;
  void emit_audio(){bool playing=false;for(auto &[id,active]:media_players)playing|=active && audio_players.contains(id);for(auto &[id,active]:audio_contexts)playing|=active;event("audio",playing?"1":"0");}
  std::map<int,std::string> protocol_operations;
  CefRefPtr<CefTaskManager> task_manager;
  int task_observers=0;
  struct CredentialContext {std::string frame_id,origin;bool main=false;};
  std::map<int,CredentialContext> credential_contexts;
  std::set<std::string> credential_frames;
  std::string credential_main_frame;
  uint64_t credential_generation=0,candidate_generation=0;
  std::string step_username,step_origin,step_frame;
  int64_t step_deadline=0;
  void clear_username_step(){std::fill(step_username.begin(),step_username.end(),'\0');step_username.clear();step_origin.clear();step_frame.clear();step_deadline=0;}
  std::string candidate_id,candidate_origin,candidate_frame,candidate_action;
  int candidate_context=0;
  gint64 candidate_at=0;
  bool candidate_network=false,candidate_dom=false;
  std::set<std::string> candidate_requests;
  uint64_t fill_serial=0;
  std::map<uint64_t,std::pair<int,int>> fill_batches;
  bool secure_fill(const std::string &site){
    if(!browser || closing || !private_key.empty() || origin(site).empty() || origin(browser->GetMainFrame()->GetURL())!=origin(site))return false;
    auto entry=browser->GetHost()->GetVisibleNavigationEntry();auto ssl=entry?entry->GetSSLStatus():nullptr;return ssl && ssl->IsSecureConnection() && ssl->GetCertStatus()==CERT_STATUS_NONE && ssl->GetContentStatus()==SSL_CONTENT_NORMAL_CONTENT && origin(site)==credential_origin;
  }
  std::string credential_origin;
  int credential_status=0;
  bool candidate_alive(){return !candidate_id.empty() && g_get_monotonic_time()-candidate_at<60*G_USEC_PER_SEC;}
  void cancel_candidate(){candidate_id.clear();candidate_origin.clear();candidate_requests.clear();candidate_network=candidate_dom=false;event("credential-cancelled","");}
  void complete_candidate(){if(!candidate_alive())return;std::string site=candidate_origin;candidate_id.clear();candidate_requests.clear();candidate_network=candidate_dom=false;event("credential-complete",site);}
  void credential_tree(CefRefPtr<CefDictionaryValue> tree,bool main,int depth=0){
    if(!tree || depth>64 || credential_frames.size()>=256)return;auto frame=tree->GetDictionary("frame");if(!frame)return;std::string id=frame->GetString("id");if(main)credential_main_frame=id;
    if(origin(frame->GetString("url"))==credential_origin && !credential_frames.contains(id)){
      credential_frames.insert(id);auto args=CefDictionaryValue::Create();args->SetString("frameId",id);args->SetString("worldName","majoris-credentials");args->SetBool("grantUniveralAccess",false);protocol("Page.createIsolatedWorld",args,"credential-world|"+std::to_string(credential_generation)+"|"+id);
    }
    auto children=tree->GetList("childFrames");if(children)for(size_t i=0;i<children->GetSize();i++)credential_tree(children->GetDictionary(i),false,depth+1);
  }
  static double certificate_time(CefBaseTime value){if(!value.val)return 0;CefTime converted;if(!cef_time_from_basetime(value,&converted))return 0;return converted.GetDoubleT();}
  void certificate(std::string url,CefRefPtr<CefX509Certificate> cert,int status,int content,bool secure){
    auto data=CefDictionaryValue::Create();CefURLParts parts;CefParseURL(url,parts);data->SetString("hostname",CefString(&parts.host));data->SetString("url",url);data->SetInt("status",status);data->SetInt("contentStatus",content);data->SetBool("secure",secure && status==CERT_STATUS_NONE && content==SSL_CONTENT_NORMAL_CONTENT);
    std::string warnings;for(auto &[flag,label]:std::map<int,std::string>{{CERT_STATUS_COMMON_NAME_INVALID,"Hostname mismatch"},{CERT_STATUS_DATE_INVALID,"Certificate validity date error"},{CERT_STATUS_AUTHORITY_INVALID,"Untrusted certificate authority"},{CERT_STATUS_REVOKED,"Certificate revoked"},{CERT_STATUS_INVALID,"Invalid certificate"}})if(status&flag)warnings+=(warnings.empty()?"":"\n")+label;data->SetString("errors",warnings);
    if(cert){data->SetString("subject",cert->GetSubject()->GetDisplayName());data->SetString("issuer",cert->GetIssuer()->GetDisplayName());data->SetDouble("validFrom",certificate_time(cert->GetValidStart()));data->SetDouble("validUntil",certificate_time(cert->GetValidExpiry()));
      std::string pem;auto append=[&](CefRefPtr<CefBinaryValue> value){if(!value || value->GetSize()>256*1024 || pem.size()>4*1024*1024)return;size_t begin=pem.size();pem.resize(begin+value->GetSize());value->GetData(pem.data()+begin,value->GetSize(),0);};append(cert->GetPEMEncoded());CefX509Certificate::IssuerChainBinaryList chain;cert->GetPEMEncodedIssuerChain(chain);for(auto &value:chain)append(value);data->SetString("pem",pem);
    }auto value=CefValue::Create();value->SetDictionary(data);event("certificate",CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString());
  }
  bool OnCertificateError(CefRefPtr<CefBrowser>,cef_errorcode_t error,const CefString &url,CefRefPtr<CefSSLInfo> ssl,CefRefPtr<CefCallback>) override {
    event("security","TLS certificate verification failed (Chromium error "+std::to_string(error)+")");certificate(url,ssl?ssl->GetX509Certificate():nullptr,ssl?ssl->GetCertStatus():CERT_STATUS_INVALID,0,false);return false;
  }
  struct CookieClear { std::string host,site;int pending=0,removed=0;bool failed=false; };
  std::unique_ptr<CookieClear> cookie_clear;
  void clear_site_cookies(const std::string &url){
    CefURLParts parts;auto site=schemeful_site(url);if(site.empty() || !CefParseURL(url,parts) || cookie_clear){event("operation-error","clear-site-cookies");return;}
    cookie_clear=std::make_unique<CookieClear>();cookie_clear->host=CefString(&parts.host);cookie_clear->site=site;
    // This target's Network agent uses its own RequestContext/StoragePartition.
    // Storage.getCookies without a browserContextId would address the default context.
    protocol("Network.getAllCookies",nullptr,"site-cookie-list");
  }
  void finish_site_cookies(){if(!cookie_clear || cookie_clear->pending)return;bool failed=cookie_clear->failed;int removed=cookie_clear->removed;cookie_clear.reset();event(failed?"operation-error":"cookies-cleared",failed?"clear-site-cookies":std::to_string(removed));}  void protocol(std::string method,CefRefPtr<CefDictionaryValue> params,std::string operation){
    if(!browser || closing)return;
    int id=++protocol_id;protocol_operations[id]=operation;
    if(!browser->GetHost()->ExecuteDevToolsMethod(id,method,params)){protocol_operations.erase(id);event("operation-error",operation);}
  }
  void OnDevToolsMethodResult(CefRefPtr<CefBrowser>,int id,bool success,const void *result,size_t size) override {
    auto it=protocol_operations.find(id);if(it==protocol_operations.end())return;
    auto operation=it->second;protocol_operations.erase(it);
    if(operation=="gtk-print-pdf"){
      if(!gtk_print_pending)return;auto value=size<=128*1024*1024?CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC):nullptr;auto data=value && value->GetType()==VTYPE_DICTIONARY?value->GetDictionary():nullptr;
      if(!success || !data || data->HasKey("exceptionDetails") || data->GetString("data").empty()){finish_gtk_print(false);return;}
      gsize length=0;auto pdf=g_base64_decode(data->GetString("data").ToString().c_str(),&length);gchar *path=nullptr;GError *error=nullptr;int fd=g_file_open_tmp("majoris-print-XXXXXX.pdf",&path,&error);bool written=fd>=0 && length>5 && !memcmp(pdf,"%PDF-",5);if(fd>=0)g_close(fd,nullptr);if(written)written=g_file_set_contents(path,reinterpret_cast<const char*>(pdf),length,&error);g_free(pdf);g_clear_error(&error);
      if(!written){if(path)g_unlink(path);g_free(path);finish_gtk_print(false);return;}gtk_print_file=path;g_free(path);CefRefPtr<Client> keep(this);request("print-job","Print page",gtk_print_file,[keep](bool accepted,std::string){keep->finish_gtk_print(accepted);});return;
    }
    if(operation.starts_with("site-storage-frame|") || operation.starts_with("site-storage-key|")){
      auto selected=operation.substr(operation.find('|')+1);auto value=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);auto data=value && value->GetType()==VTYPE_DICTIONARY?value->GetDictionary():nullptr;
      if(!success || !data || !browser || origin(browser->GetMainFrame()->GetURL())!=selected){event("operation-error","clear-site-data");return;}
      auto args=CefDictionaryValue::Create();
      if(operation.starts_with("site-storage-frame|")){auto tree=data->GetDictionary("frameTree");auto frame=tree?tree->GetDictionary("frame"):nullptr;if(!frame || origin(frame->GetString("url"))!=selected){event("operation-error","clear-site-data");return;}args->SetString("frameId",frame->GetString("id"));protocol("Storage.getStorageKeyForFrame",args,"site-storage-key|"+selected);}
      else {auto key=data->GetString("storageKey");if(key.empty()){event("operation-error","clear-site-data");return;}args->SetString("storageKey",key);args->SetString("storageTypes","file_systems,indexeddb,local_storage,websql,service_workers,cache_storage,storage_buckets");protocol("Storage.clearDataForStorageKey",args,"clear-site-data");}return;
    }    if(operation=="site-cookie-list"){
      if(!cookie_clear)return;auto value=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);auto data=value && value->GetType()==VTYPE_DICTIONARY?value->GetDictionary():nullptr;auto cookies=data?data->GetList("cookies"):nullptr;
      if(!success || !cookies){cookie_clear->failed=true;finish_site_cookies();return;}
      std::vector<CefRefPtr<CefDictionaryValue>> deletions;
      for(size_t i=0;i<cookies->GetSize();i++){
        auto cookie=cookies->GetDictionary(i);if(!cookie)continue;std::string domain=cookie->GetString("domain"),plain=domain;bool shared=plain.starts_with('.');if(shared)plain.erase(0,1);const auto &host=cookie_clear->host;
        if(!(host==plain || (shared && host.size()>plain.size() && host.ends_with("."+plain))))continue;
        if(cookie->HasKey("partitionKeyOpaque") && cookie->GetBool("partitionKeyOpaque"))continue;
        auto partition=cookie->GetDictionary("partitionKey");
        if(cookie->HasKey("partitionKey") && (!partition || partition->GetString("topLevelSite")!=cookie_clear->site))continue;
        auto args=CefDictionaryValue::Create();args->SetString("name",cookie->GetString("name"));args->SetString("domain",domain);args->SetString("path",cookie->GetString("path"));if(partition)args->SetDictionary("partitionKey",partition->Copy(false));deletions.push_back(args);
      }
      cookie_clear->pending=deletions.size();for(auto args:deletions)protocol("Network.deleteCookies",args,"site-cookie-delete");finish_site_cookies();return;
    }
    if(operation=="site-cookie-delete"){if(cookie_clear){if(success)cookie_clear->removed++;else cookie_clear->failed=true;cookie_clear->pending--;finish_site_cookies();}return;}
    if(operation=="cookie-inventory"){
      auto value=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);auto data=value && value->GetType()==VTYPE_DICTIONARY?value->GetDictionary():nullptr;auto cookies=data?data->GetList("cookies"):nullptr;std::string summary;
      if(success && cookies)for(size_t i=0;i<cookies->GetSize();i++){auto cookie=cookies->GetDictionary(i);if(cookie){auto key=cookie->GetDictionary("partitionKey");summary+=cookie->GetString("name").ToString()+"\t"+(key?key->GetString("topLevelSite").ToString():"")+"\n";}}else{event("operation-error","cookie-inventory");return;}event("cookie-inventory",summary);return;
    }    if(operation=="partition-cookie-set"){event("cookie-set",success?"1":"0");return;}    if(operation.starts_with("autofill|")){
      uint64_t batch=g_ascii_strtoull(operation.c_str()+9,nullptr,10);auto found=fill_batches.find(batch);if(found==fill_batches.end())return;
      auto parsed=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);if(success && parsed && parsed->GetType()==VTYPE_DICTIONARY && !parsed->GetDictionary()->HasKey("exceptionDetails")){auto value=parsed->GetDictionary()->GetDictionary("result");if(value && value->GetInt("value")>0)found->second.second++;}
      if(--found->second.first==0){int count=found->second.second;fill_batches.erase(found);event(count?"credential-filled":"credential-fill-refused",count?std::to_string(count):"No visible matching login field is available");}return;
    }
    if(operation=="address-fill"){
      auto parsed=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);int count=0;if(success && parsed && parsed->GetType()==VTYPE_DICTIONARY && !parsed->GetDictionary()->HasKey("exceptionDetails")){auto value=parsed->GetDictionary()->GetDictionary("result");if(value)count=value->GetInt("value");}event(count?"address-filled":"address-fill-refused",std::to_string(count));return;
    }
    if(operation.starts_with("context-hit:") || operation.starts_with("context-resolve:") || operation.starts_with("context-execute:")){
      auto suffix=operation.substr(operation.find(':')+1);auto separator=suffix.find('|');if(separator==std::string::npos || suffix.substr(separator+1)!=std::to_string(context_generation))return;
      auto action=suffix.substr(0,separator);auto parsed=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);
      if(!success || !parsed || parsed->GetType()!=VTYPE_DICTIONARY || parsed->GetDictionary()->HasKey("exceptionDetails")){event("operation-error","The selected media action is unavailable");return;}auto data=parsed->GetDictionary();auto args=CefDictionaryValue::Create();
      if(operation.starts_with("context-hit:")){args->SetInt("backendNodeId",data->GetInt("backendNodeId"));args->SetString("objectGroup","majoris-context");protocol("DOM.resolveNode",args,"context-resolve:"+suffix);}
      else if(operation.starts_with("context-resolve:")){
        auto object=data->GetDictionary("object");if(!object)return;args->SetString("objectId",object->GetString("objectId"));args->SetBool("userGesture",true);args->SetBool("awaitPromise",true);args->SetBool("returnByValue",true);
        std::string body=action=="play"?"return e.play();":action=="pause"?"e.pause();":action=="mute"?"e.muted=true;":action=="unmute"?"e.muted=false;":"if(e.tagName!=='VIDEO'||e.disablePictureInPicture)throw Error('Unavailable');return document.pictureInPictureElement===e?document.exitPictureInPicture():e.requestPictureInPicture();";
        args->SetString("functionDeclaration","function(){let e=this;while(e&&!['VIDEO','AUDIO'].includes(e.tagName))e=e.parentElement||e.getRootNode()?.host;if(!e)throw Error('Unavailable');"+body+"}");protocol("Runtime.callFunctionOn",args,"context-execute:"+suffix);
      }else{event("operation-complete","context-media");args->SetString("objectGroup","majoris-context");protocol("Runtime.releaseObjectGroup",args,"context-release");}return;
    }
    if(operation=="picture-in-picture"){
      auto data=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);bool failed=!success || !data || data->GetType()!=VTYPE_DICTIONARY || data->GetDictionary()->HasKey("exceptionDetails");event(failed?"operation-error":"operation-complete",failed?"Picture-in-picture is unavailable for this media":operation);return;
    }
    if(operation=="print" || operation=="save-pdf" || operation=="save-page"){
      if(!success){event("operation-error",operation);return;}auto parsed=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);if(!parsed || parsed->GetType()!=VTYPE_DICTIONARY)return;
      auto data=parsed->GetDictionary()->GetString("data").ToString();if(data.size()>64*1024*1024){event("operation-error",operation+": output exceeds 64 MiB");return;}event(operation,data);return;
    }
    if(operation.starts_with("credential-")){
      auto fields=g_strsplit(operation.c_str(),"|",3);std::string kind=fields[0]?fields[0]:"",generation=fields[1]?fields[1]:"",key=fields[1]&&fields[2]?fields[2]:"";g_strfreev(fields);
      if(generation!=std::to_string(credential_generation) || !success || closing)return;
      auto parsed=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);if(!parsed || parsed->GetType()!=VTYPE_DICTIONARY)return;auto data=parsed->GetDictionary();
      if(kind=="credential-frame")credential_tree(data->GetDictionary("frameTree"),true);
      else if(kind=="credential-world"){
        int context=data->GetInt("executionContextId");if(context<=0)return;credential_contexts[context]={key,credential_origin,key==credential_main_frame};auto args=CefDictionaryValue::Create();args->SetString("name","majorisCredentialSubmit");args->SetInt("executionContextId",context);protocol("Runtime.addBinding",args,"credential-binding|"+generation+"|"+std::to_string(context));
      }else if(kind=="credential-binding"){
        int context=static_cast<int>(g_ascii_strtoll(key.c_str(),nullptr,10));if(!credential_contexts.contains(context))return;auto args=CefDictionaryValue::Create();args->SetInt("contextId",context);args->SetString("expression",credential_observer);protocol("Runtime.evaluate",args,"credential-observer|"+generation+"|"+key);
      }else if(kind=="credential-observer"){
        int context=static_cast<int>(g_ascii_strtoll(key.c_str(),nullptr,10));auto found=credential_contexts.find(context);auto value=data->GetDictionary("result");
        if(found!=credential_contexts.end() && value && !data->HasKey("exceptionDetails")){
          event("form-observer-ready",credential_origin);
          if(value->GetBool("value"))event("credential-form",credential_origin);
          else if(candidate_alive() && found->second.main && credential_status>=200 && credential_status<400 && candidate_generation<credential_generation && candidate_origin==credential_origin)complete_candidate();
          else if(candidate_alive() && found->second.frame_id==candidate_frame && candidate_network && context!=candidate_context)complete_candidate();
        }
      }return;
    }
    if(operation=="evaluate"){event("evaluation",success?std::string(static_cast<const char*>(result),size):"{}");return;}
    if(success && operation=="picture-in-picture"){auto value=CefParseJSON(std::string(static_cast<const char*>(result),size),JSON_PARSER_RFC);if(value && value->GetType()==VTYPE_DICTIONARY && value->GetDictionary()->HasKey("exceptionDetails"))success=false;}
    event(success?"operation-complete":"operation-error",operation);
  }
  void OnDevToolsEvent(CefRefPtr<CefBrowser>,const CefString &method,const void *params,size_t size) override {
    if(method=="WebAudio.contextCreated" || method=="WebAudio.contextChanged" || method=="WebAudio.contextWillBeDestroyed" || method=="Media.playerPropertiesChanged"){
      auto parsed=CefParseJSON(std::string(static_cast<const char*>(params),size),JSON_PARSER_RFC);if(!parsed || parsed->GetType()!=VTYPE_DICTIONARY)return;auto data=parsed->GetDictionary();
      if(method=="WebAudio.contextWillBeDestroyed")audio_contexts.erase(data->GetString("contextId"));
      else if(method=="Media.playerPropertiesChanged"){
        auto properties=data->GetList("properties");if(properties)for(size_t i=0;i<properties->GetSize();i++){auto property=properties->GetDictionary(i);if(property && property->GetString("name")=="kAudioTracks"){auto value=property->GetString("value").ToString();if(value!="[]" && !value.empty())audio_players.insert(data->GetString("playerId"));else audio_players.erase(data->GetString("playerId"));}}
      }else{auto context=data->GetDictionary("context");if(context)audio_contexts[context->GetString("contextId")]=context->GetString("contextState")=="running";}
      emit_audio();return;
    }
    if(method=="Runtime.executionContextDestroyed"){
      auto parsed=CefParseJSON(std::string(static_cast<const char*>(params),size),JSON_PARSER_RFC);if(parsed && parsed->GetType()==VTYPE_DICTIONARY){int id=parsed->GetDictionary()->GetInt("executionContextId");auto found=credential_contexts.find(id);if(found!=credential_contexts.end()){credential_frames.erase(found->second.frame_id);credential_contexts.erase(found);}}return;
    }
    if(method=="Network.requestWillBeSent" || method=="Network.responseReceived"){
      if(!candidate_alive())return;auto parsed=CefParseJSON(std::string(static_cast<const char*>(params),size),JSON_PARSER_RFC);if(!parsed || parsed->GetType()!=VTYPE_DICTIONARY)return;auto data=parsed->GetDictionary();std::string id=data->GetString("requestId");
      if(method=="Network.requestWillBeSent"){
        auto request=data->GetDictionary("request");if(!request || data->GetString("frameId")!=candidate_frame || origin(request->GetString("url"))!=candidate_origin)return;
        auto verb=request->GetString("method");if(verb!="POST" && verb!="PUT" && verb!="PATCH")return;
        CefURLParts parts;CefParseURL(request->GetString("url"),parts);std::string path=CefString(&parts.path);std::transform(path.begin(),path.end(),path.begin(),[](unsigned char c){return g_ascii_tolower(c);});
        bool credential_path=path.find("login")!=std::string::npos || path.find("signin")!=std::string::npos || path.find("session")!=std::string::npos || path.find("auth")!=std::string::npos || path.find("password")!=std::string::npos || path.find("account")!=std::string::npos;
        if(data->GetString("type")=="Document" || credential_path || request->GetString("url")==candidate_action){candidate_requests.insert(id);event("credential-progress","request");}
      }else if(candidate_requests.contains(id)){
        auto response=data->GetDictionary("response");if(!response || origin(response->GetString("url"))!=candidate_origin)return;double status=response->GetType("status")==VTYPE_INT?response->GetInt("status"):response->GetDouble("status");event("credential-progress","response:"+std::to_string(static_cast<int>(status)));if(status>=200 && status<400){candidate_network=true;if(candidate_dom)complete_candidate();}else if(status>=400)cancel_candidate();
      }return;
    }
    if(method=="Runtime.bindingCalled"){
      auto parsed=CefParseJSON(std::string(static_cast<const char*>(params),size),JSON_PARSER_RFC);if(!parsed || parsed->GetType()!=VTYPE_DICTIONARY)return;auto data=parsed->GetDictionary();int context=data->GetInt("executionContextId");auto found=credential_contexts.find(context);
      if(data->GetString("name")!="majorisCredentialSubmit" || found==credential_contexts.end() || !browser || origin(browser->GetMainFrame()->GetURL())!=credential_origin || found->second.origin!=credential_origin || data->GetString("payload").length()>24576)return;
      auto payload=CefParseJSON(data->GetString("payload"),JSON_PARSER_RFC);if(!payload || payload->GetType()!=VTYPE_DICTIONARY)return;auto value=payload->GetDictionary();auto kind=value->GetString("kind");
      if(kind=="username-step"){
        auto name=value->GetString("username").ToString();if(name.empty() || name.size()>1024)return;
        clear_username_step();step_username=name;step_origin=credential_origin;step_frame=found->second.frame_id;step_deadline=g_get_monotonic_time()+60*G_USEC_PER_SEC;
        auto deadline=step_deadline;CefRefPtr<Client> keep=this;CefPostDelayedTask(TID_UI,new Task([keep,deadline]{if(keep->step_deadline==deadline)keep->clear_username_step();}),60000);return;
      }
      if(kind=="form"){event("credential-form",credential_origin);return;}
      if(kind=="address"){auto safe=CefDictionaryValue::Create();safe->SetString("origin",credential_origin);safe->SetInt("context",context);auto result=CefValue::Create();result->SetDictionary(safe);event("address-offer",CefWriteJSON(result,JSON_WRITER_DEFAULT).ToString());return;}
      if(kind=="outcome"){if(candidate_alive() && value->GetString("id")==candidate_id && context==candidate_context){candidate_dom=true;event("credential-progress","dom-outcome");if(candidate_network)complete_candidate();}return;}
      if(kind!="submit" || value->GetString("id").empty() || value->GetString("id").length()>128 || value->GetString("password").empty() || value->GetString("password").length()>4096 || value->GetString("username").length()>1024)return;
      std::string action=value->GetString("action");if(action.size()>8192 || (!action.empty() && origin(action)!=credential_origin))return;
      if(value->GetString("username").empty() && step_origin==credential_origin && step_frame==found->second.frame_id && g_get_monotonic_time()<step_deadline)value->SetString("username",step_username);
      clear_username_step();
      candidate_id=value->GetString("id");candidate_origin=credential_origin;candidate_frame=found->second.frame_id;candidate_context=context;candidate_generation=credential_generation;candidate_action=action;candidate_at=g_get_monotonic_time();candidate_requests.clear();candidate_network=candidate_dom=false;
      value->SetString("origin",credential_origin);event("credential-submit",CefWriteJSON(payload,JSON_WRITER_DEFAULT).ToString());return;
    }
    if(method!="Media.playerEventsAdded")return;
    auto parsed=CefParseJSON(std::string(static_cast<const char*>(params),size),JSON_PARSER_RFC);if(!parsed || parsed->GetType()!=VTYPE_DICTIONARY)return;
    auto data=parsed->GetDictionary();auto events=data->GetList("events");if(!events)return;
    for(size_t i=0;i<events->GetSize();i++){auto item=events->GetDictionary(i);if(!item)continue;auto payload=CefParseJSON(item->GetString("value"),JSON_PARSER_RFC);if(!payload || payload->GetType()!=VTYPE_DICTIONARY)continue;
      auto name=payload->GetDictionary()->GetString("event").ToString();if(name=="kPlay")media_players[data->GetString("playerId")]=true;else if(name=="kPause" || name=="kEnded")media_players[data->GetString("playerId")]=false;
    }emit_audio();
  }
  std::vector<uint8_t> view_pixels,popup_pixels;
  int pixel_width=0,pixel_height=0,popup_width=0,popup_height=0;
  CefRect popup_rect;
  bool popup_visible=false;
  std::mutex frame_mutex;
  GBytes *pending_frame=nullptr;
  int pending_width=0,pending_height=0;
  bool frame_queued=false;
  Client(McView *v, std::string scope):scope(std::move(scope)) { g_weak_ref_init(&view,v); }
  ~Client() override {if(!gtk_print_file.empty())g_unlink(gtk_print_file.c_str());if(pending_frame)g_bytes_unref(pending_frame);g_weak_ref_clear(&view);}
  void event(std::string kind, std::string value) {
    CefRefPtr<Client> keep(this);
    gtk([keep,kind=std::move(kind),value=std::move(value)] {
      auto *v = static_cast<McView*>(g_weak_ref_get(&keep->view));
      if (v) { g_signal_emit(v,signals[1],0,kind.c_str(),value.c_str()); g_object_unref(v); }
    });
  }
  int request(std::string kind, std::string origin, std::string message, std::function<void(bool,std::string)> cb) {
    int id=++token;
    replies.emplace(id,std::move(cb));
    reply_kinds[id]=kind;
    CefRefPtr<Client> keep(this);
    gtk([keep,id,kind=std::move(kind),origin=std::move(origin),message=std::move(message)] {
      auto *v=static_cast<McView*>(g_weak_ref_get(&keep->view));
      if (v) { g_signal_emit(v,signals[2],0,id,kind.c_str(),origin.c_str(),message.c_str()); g_object_unref(v); }
      else ui([keep,id] { keep->reply(id,false,""); });
    });
    return id;
  }
  void reply(int id,bool yes,std::string text) {
    auto it=replies.find(id); if (it==replies.end()) return;
    auto cb=std::move(it->second);replies.erase(it);reply_kinds.erase(id);cb(yes,std::move(text));
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
      auto normalized=[](const std::string &url){gchar *resolved=g_uri_resolve_relative(url.c_str(),"",G_URI_FLAGS_ENCODED_PATH,nullptr);GUri *parsed=resolved?g_uri_parse(resolved,G_URI_FLAGS_ENCODED_PATH,nullptr):nullptr;std::string path=parsed?g_uri_get_path(parsed):"";if(parsed)g_uri_unref(parsed);g_free(resolved);std::string lower=path;std::transform(lower.begin(),lower.end(),lower.begin(),[](unsigned char c){return g_ascii_tolower(c);});if(path.find('\\')!=std::string::npos || lower.find("%2e")!=std::string::npos || lower.find("%2f")!=std::string::npos || lower.find("%5c")!=std::string::npos)return std::string();return path.empty()?std::string("/"):path;};
      std::string path=normalized(url), base=normalized(scope);
      auto port=[](GUri *v) { int p=g_uri_get_port(v); return p<0 ? (g_strcmp0(g_uri_get_scheme(v),"https")==0 ? 443:80):p; };
      bool boundary=!path.empty() && !base.empty() && (path==base || path.rfind(base+(base.ends_with('/')?"":"/"),0)==0);
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
  CefRefPtr<CefFocusHandler> GetFocusHandler() override {return this;}
  void OnTakeFocus(CefRefPtr<CefBrowser>,bool next) override {event("focus-escape",next?"1":"0");}
  bool OnSetFocus(CefRefPtr<CefBrowser>,FocusSource source) override {if(source==FOCUS_SOURCE_SYSTEM)event("focus-request","");return false;}
  CefRefPtr<CefPrintHandler> GetPrintHandler() override {return this;}
  CefSize print_paper=CefSize(2480,3508); // paper dimensions at 300 DPI
  bool gtk_print_pending=false,gtk_print_pdf_started=false;
  bool print_landscape=false;
  std::string gtk_print_file;
  void finish_gtk_print(bool accepted){if(!gtk_print_file.empty()){g_unlink(gtk_print_file.c_str());gtk_print_file.clear();}gtk_print_pending=gtk_print_pdf_started=false;event("print-result",accepted?"submitted":"cancelled-or-failed");event("print-reset","");}
  void OnPrintStart(CefRefPtr<CefBrowser>) override {}
  void OnPrintSettings(CefRefPtr<CefBrowser>,CefRefPtr<CefPrintSettings> settings,bool defaults) override {if(defaults){settings->SetDPI(300);settings->SetOrientation(false);settings->SetPrinterPrintableArea(CefSize(2480,3508),CefRect(0,0,2480,3508),false);}}
  bool OnPrintDialog(CefRefPtr<CefBrowser>,bool,CefRefPtr<CefPrintDialogCallback> callback) override {
    if(gtk_print_pending){callback->Cancel();return true;}
    CefRefPtr<Client> keep(this);request("print-setup","Print page","",[keep,callback](bool yes,std::string text){
      auto value=CefParseJSON(text,JSON_PARSER_RFC);if(!yes || !value || value->GetType()!=VTYPE_DICTIONARY){callback->Cancel();return;}auto data=value->GetDictionary();int width=data->GetInt("width"),height=data->GetInt("height");if(width<=0 || height<=0 || width>30000 || height>30000){callback->Cancel();return;}keep->print_paper=CefSize(width,height);keep->print_landscape=data->GetBool("landscape");keep->gtk_print_pending=true;callback->Cancel();
    });return true;
  }
  bool OnPrintJob(CefRefPtr<CefBrowser>,const CefString&,const CefString &path,CefRefPtr<CefPrintJobCallback> callback) override {CefRefPtr<Client> keep(this);request("print-job","Print page",path.ToString(),[keep,callback](bool accepted,std::string){keep->event("print-result",accepted?"submitted":"cancelled-or-failed");callback->Continue();});return true;}
  void OnPrintReset(CefRefPtr<CefBrowser>) override {
    if(gtk_print_pending){if(!gtk_print_pdf_started){gtk_print_pdf_started=true;auto args=CefDictionaryValue::Create();args->SetBool("printBackground",true);args->SetBool("landscape",print_landscape);args->SetDouble("paperWidth",print_paper.width/300.0);args->SetDouble("paperHeight",print_paper.height/300.0);protocol("Page.printToPDF",args,"gtk-print-pdf");}return;}event("print-reset","");
  }
  CefSize GetPdfPaperSize(CefRefPtr<CefBrowser>,int dpi) override {return CefSize(std::max(1,print_paper.width*dpi/300),std::max(1,print_paper.height*dpi/300));}
  void OnAfterCreated(CefRefPtr<CefBrowser> b) override {
    if(opener){opener->popup_children.erase(popup_id);opener=nullptr;}
    browser=b;devtools_registration=b->GetHost()->AddDevToolsMessageObserver(this);
    if(accessibility_enabled)b->GetHost()->SetAccessibilityState(STATE_ENABLED);
    auto params=CefDictionaryValue::Create();params->SetString("userAgent",user_agent());params->SetString("platform","Linux x86_64");
    auto metadata=CefDictionaryValue::Create();metadata->SetString("platform","Linux");metadata->SetString("platformVersion","");metadata->SetString("architecture","x86");metadata->SetString("bitness","64");metadata->SetString("model","");metadata->SetBool("mobile",false);metadata->SetString("fullVersion",chrome_version());
    for(auto field:{"brands","fullVersionList"}){auto list=CefListValue::Create();auto brand=CefDictionaryValue::Create();brand->SetString("brand","Chromium");brand->SetString("version",std::string(field)=="brands"?std::to_string(cef_version_info(4)):chrome_version());list->SetDictionary(0,brand);auto majoris=CefDictionaryValue::Create();majoris->SetString("brand","Majoris");majoris->SetString("version",std::string(field)=="brands"?std::string(MAJORIS_VERSION).substr(0,std::string(MAJORIS_VERSION).find('.')):MAJORIS_VERSION);list->SetDictionary(1,majoris);metadata->SetList(field,list);}params->SetDictionary("userAgentMetadata",metadata);
    protocol("Emulation.setUserAgentOverride",params,"user-agent");protocol("Runtime.enable",nullptr,"runtime-events");protocol("Media.enable",nullptr,"media-events");protocol("WebAudio.enable",nullptr,"web-audio-events");protocol("Network.enable",nullptr,"network-events");g_message("CEF: view ready");event("ready",""); if(closing) b->GetHost()->CloseBrowser(true);else if(close_requested)b->GetHost()->CloseBrowser(false);
  }
  bool DoClose(CefRefPtr<CefBrowser>) override {closing=true;return false;}
  void OnBeforeClose(CefRefPtr<CefBrowser>) override {
    clear_username_step();cancel_candidate();credential_contexts.clear();credential_frames.clear();
    revoke_auth("window-closed");
    end_drag(-1,-1,DRAG_OPERATION_NONE);
    for(auto &site:temporary_permission_origins)apply_permissions(site);temporary_permission_origins.clear();
    auto pending=std::move(replies); for(auto &[id,cb]:pending) cb(false,"");
    if(!private_key.empty()){auto it=private_contexts.find(private_key);if(it!=private_contexts.end() && --it->second.second==0)private_contexts.erase(it);}
    if(manifest_request){manifest_request->Cancel();manifest_request=nullptr;}
    for(auto &[id,callback]:downloads)callback->Cancel();downloads.clear();
    devtools_registration=nullptr;protocol_operations.clear();task_manager=nullptr;browser=nullptr;context=nullptr;event("closed","");
    { std::lock_guard lock(lifecycle_mutex); --live; } lifecycle_cv.notify_all();
  }
  bool OnBeforePopup(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> source,int id,const CefString &url,const CefString&,cef_window_open_disposition_t disposition,bool gesture,const CefPopupFeatures&,CefWindowInfo &window,CefRefPtr<CefClient> &client,CefBrowserSettings&,CefRefPtr<CefDictionaryValue>&,bool*) override {
    event("popup-request",gesture?"gesture":"no-gesture");
    if(closing)return true;
    std::string back,state;bool candidate=!scope.empty() && AuthFlow::candidate(url,[this](auto &target){return in_scope(target);},back,state);
    bool flow=auth_flow && auth_flow->alive();bool trusted=source && !scope.empty() && (in_scope(source->GetURL()) || (flow && auth_flow->origins.contains(AuthFlow::origin(source->GetURL()))));
    CefURLParts initiator;bool popup_permission=source && CefParseURL(source->GetURL(),initiator) && permission_policy[CefString(&initiator.origin)]["popups"]==1;
    if(candidate && !trusted){event("external-untrusted",url);return true;}
    if(!gesture && !popup_permission && !(trusted && (candidate || (flow && (in_scope(url) || auth_flow->origins.contains(AuthFlow::origin(url))))))){event("popup-blocked",url);return true;}
    if(candidate && (!flow || auth_flow->return_uri!=back || auth_flow->state!=state)){
      revoke_auth("new-popup-flow");auth_flow=std::make_shared<AuthFlow>();auth_flow->initiator=AuthFlow::origin(source->GetURL());auth_flow->return_uri=back;auth_flow->state=state;
    }
    auto *child=static_cast<McView*>(g_object_new(MC_TYPE_VIEW,nullptr));auto keep=CefRefPtr<Client>(new Client(child,scope));child->state->client=keep;child->state->auth_popup=candidate || (flow && trusted);keep->context=context;keep->opener=this;keep->popup_id=id;keep->auth_flow=auth_flow;keep->permission_policy=permission_policy;keep->threat_checks=threat_checks.load();
    if(!private_key.empty()){keep->private_key=private_key;++private_contexts[private_key].second;}
    popup_children[id]=keep;{std::lock_guard lock(lifecycle_mutex);++live;}
    window.SetAsWindowless(0);window.runtime_style=CEF_RUNTIME_STYLE_ALLOY;client=keep;
    CefRefPtr<Client> parent(this);bool background=disposition==CEF_WOD_NEW_BACKGROUND_TAB,new_window=disposition==CEF_WOD_NEW_WINDOW || disposition==CEF_WOD_NEW_POPUP;std::string target=url;
    gtk([parent,child,background,target,new_window]{auto *view=static_cast<McView*>(g_weak_ref_get(&parent->view));if(view){g_signal_emit(view,signals[3],0,child,background,target.c_str(),new_window);g_object_unref(view);}else mc_view_close(child);g_object_unref(child);});return false;
  }
  void OnBeforePopupAborted(CefRefPtr<CefBrowser>,int id) override {
    auto it=popup_children.find(id);if(it==popup_children.end())return;auto child=it->second;popup_children.erase(it);child->opener=nullptr;
    if(!child->private_key.empty()){auto found=private_contexts.find(child->private_key);if(found!=private_contexts.end() && --found->second.second==0)private_contexts.erase(found);child->private_key.clear();}
    child->context=nullptr;child->closing=true;child->event("error","Popup creation was cancelled");child->event("closed","");{std::lock_guard lock(lifecycle_mutex);--live;}g_main_context_wakeup(g_main_context_default());
  }
  bool OnBeforeBrowse(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> f,CefRefPtr<CefRequest> r,bool gesture,bool redirect) override {
    CefURLParts parts;if(CefParseURL(r->GetURL(),parts) && (CefString(&parts.scheme)=="https" || CefString(&parts.scheme)=="http"))apply_permissions(CefString(&parts.origin));
    if(f->IsMain()){
      if(threat_checks)event("threat-navigation",r->GetURL());


      auto target=r->GetURL().ToString();
      if(in_scope(target)){if(auth_flow && auth_flow->active){bool returned=auth_flow->returned(target);event(returned?"auth-returned":"auth-cancelled",returned?auth_flow->id:"Returned outside the approved callback URI/state");revoke_auth(returned?"returned":"cancelled");}return false;}
      if(auth_flow && auth_flow->alive()){
        if(auth_flow->origins.contains(AuthFlow::origin(target)))return false;
        if(redirect && !gesture && !origin(target).empty()){pending_auth_redirect=target;event("auth-intermediate",target);return true;}
      }else if(auth_flow && auth_flow->active)revoke_auth("expired");
      event("external",target);return true;
    }return false;
  }
  bool OnOpenURLFromTab(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame>,const CefString &url,cef_window_open_disposition_t disposition,bool gesture) override {
    if(gesture) event(disposition==CEF_WOD_NEW_BACKGROUND_TAB?"popup-background":disposition==CEF_WOD_NEW_WINDOW?"popup-window":"popup",url.ToString()); return true;
  }
  void GetViewRect(CefRefPtr<CefBrowser>,CefRect &r) override { r=CefRect(0,0,width,height); }
  bool GetScreenInfo(CefRefPtr<CefBrowser>,CefScreenInfo &i) override { i.device_scale_factor=scale; i.rect=CefRect(0,0,width,height); i.available_rect=i.rect; return true; }
  void OnPopupShow(CefRefPtr<CefBrowser> b,bool visible) override {popup_visible=visible;if(!visible){popup_pixels.clear();b->GetHost()->Invalidate(PET_VIEW);}}
  void OnPopupSize(CefRefPtr<CefBrowser>,const CefRect &rect) override {popup_rect=rect;}
  void OnImeCompositionRangeChanged(CefRefPtr<CefBrowser>,const CefRange &range,const RectList &bounds) override {
    if(bounds.empty())return;size_t index=std::min<size_t>(range.to,bounds.size()-1);const auto &rect=bounds[index];event("ime-caret",std::to_string(rect.x)+","+std::to_string(rect.y)+","+std::to_string(rect.width)+","+std::to_string(rect.height));
  }
  void OnPaint(CefRefPtr<CefBrowser>,PaintElementType type,const RectList&,const void *buffer,int w,int h) override {
    if(closing || w<=0 || h<=0)return;
    const auto *input=static_cast<const uint8_t*>(buffer);
    if(type==PET_VIEW){pixel_width=w;pixel_height=h;view_pixels.assign(input,input+static_cast<size_t>(w)*h*4);}
    else {popup_width=w;popup_height=h;popup_pixels.assign(input,input+static_cast<size_t>(w)*h*4);}
    if(view_pixels.empty())return;
    std::vector<uint8_t> composed;const uint8_t *output=view_pixels.data();
    if(popup_visible && !popup_pixels.empty()){
      composed=view_pixels;output=composed.data();
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
      pending_frame=g_bytes_new(output,view_pixels.size());pending_width=pixel_width;pending_height=pixel_height;
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
  void OnFaviconURLChange(CefRefPtr<CefBrowser> b,const std::vector<CefString>& urls) override {if(!urls.empty())b->GetHost()->DownloadImage(urls.front(),true,64,false,image_callback(this,"favicon"));}
  void OnFullscreenModeChange(CefRefPtr<CefBrowser>,bool full) override {event("fullscreen",full?"1":"0");}
  bool OnCursorChange(CefRefPtr<CefBrowser>,CefCursorHandle,cef_cursor_type_t type,const CefCursorInfo&) override {
    event("cursor",type==CT_HAND?"pointer":type==CT_IBEAM?"text":type==CT_WAIT?"wait":type==CT_CROSS?"crosshair":"default");return true;
  }
  void OnAddressChange(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> f,const CefString &s) override { if(f->IsMain()){if(origin(s)!=step_origin)clear_username_step();if(candidate_alive() && origin(s)!=candidate_origin)cancel_candidate();event("url",s.ToString());} }
  void OnLoadStart(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> frame,cef_transition_type_t) override {
    if(!frame->IsMain())return;
    media_players.clear();audio_players.clear();audio_contexts.clear();emit_audio();++context_generation;context_source.clear();
    ++credential_generation;credential_contexts.clear();credential_frames.clear();credential_origin.clear();credential_status=0;event("navigation-started","");
  }
  void OnLoadEnd(CefRefPtr<CefBrowser> browser,CefRefPtr<CefFrame> frame,int status) override {
    if(!frame->IsMain()){if(private_key.empty() && !credential_origin.empty() && origin(frame->GetURL())==credential_origin)protocol("Page.getFrameTree",nullptr,"credential-frame|"+std::to_string(credential_generation));return;}
    auto entry=browser->GetHost()->GetVisibleNavigationEntry();auto ssl=entry?entry->GetSSLStatus():nullptr;
    std::string description="Connection is not encrypted";
    if(ssl && ssl->IsSecureConnection()){
      description=ssl->GetCertStatus()==CERT_STATUS_NONE && ssl->GetContentStatus()==SSL_CONTENT_NORMAL_CONTENT?"Encrypted TLS connection":"TLS connection has certificate or mixed-content warnings";
      description+="\nCertificate status: "+std::to_string(ssl->GetCertStatus())+"\nContent status: "+std::to_string(ssl->GetContentStatus());
      auto cert=ssl->GetX509Certificate();if(cert)description+="\nSubject: "+cert->GetSubject()->GetDisplayName().ToString()+"\nIssuer: "+cert->GetIssuer()->GetDisplayName().ToString();
    }
    event("security",description);
    certificate(frame->GetURL(),ssl?ssl->GetX509Certificate():nullptr,ssl?ssl->GetCertStatus():0,ssl?ssl->GetContentStatus():0,ssl && ssl->IsSecureConnection());
    if(private_key.empty() && ssl && ssl->IsSecureConnection() && ssl->GetCertStatus()==CERT_STATUS_NONE && ssl->GetContentStatus()==SSL_CONTENT_NORMAL_CONTENT){credential_status=status;credential_origin=origin(frame->GetURL());protocol("Page.getFrameTree",nullptr,"credential-frame|"+std::to_string(credential_generation));}
  }
  bool OnTooltip(CefRefPtr<CefBrowser>,CefString &s) override { event("tooltip",s.ToString()); return true; }
  void OnLoadingStateChange(CefRefPtr<CefBrowser>,bool loading,bool back,bool forward) override { event("loading",loading?"1":"0"); event("back",back?"1":"0"); event("forward",forward?"1":"0"); }
  void OnLoadError(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame> f,ErrorCode code,const CefString &text,const CefString&) override { if(f->IsMain() && code!=ERR_ABORTED) event("error",text.ToString()); }
  void OnRenderProcessTerminated(CefRefPtr<CefBrowser>,TerminationStatus,int,const CefString &s) override {media_players.clear();audio_players.clear();audio_contexts.clear();emit_audio();event("crashed",s.ToString());}
  void OnBeforeContextMenu(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame>,CefRefPtr<CefContextMenuParams> p,CefRefPtr<CefMenuModel> model) override {
    model->Clear();context_x=p->GetXCoord();context_y=p->GetYCoord();context_source=p->GetSourceUrl();++context_generation;
    auto descriptor=CefDictionaryValue::Create();descriptor->SetString("link",p->GetLinkUrl());descriptor->SetString("source",p->GetSourceUrl());descriptor->SetString("selection",p->GetSelectionText());descriptor->SetBool("editable",p->IsEditable());descriptor->SetInt("editFlags",p->GetEditStateFlags());descriptor->SetInt("media",p->GetMediaType());descriptor->SetInt("mediaFlags",p->GetMediaStateFlags());descriptor->SetInt("x",context_x);descriptor->SetInt("y",context_y);
    std::vector<CefString> words;p->GetDictionarySuggestions(words);auto suggestions=CefListValue::Create();for(size_t i=0;i<words.size() && i<5;i++)suggestions->SetString(i,words[i]);descriptor->SetList("suggestions",suggestions);descriptor->SetString("misspelled",p->GetMisspelledWord());auto value=CefValue::Create();value->SetDictionary(descriptor);event("context",CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString());
  }
  bool OnJSDialog(CefRefPtr<CefBrowser>,const CefString &origin,JSDialogType type,const CefString &message,const CefString &initial,CefRefPtr<CefJSDialogCallback> cb,bool&) override {
    std::string body=message.ToString();if(type==JSDIALOGTYPE_PROMPT){auto data=CefDictionaryValue::Create();data->SetString("message",message);data->SetString("default",initial);auto value=CefValue::Create();value->SetDictionary(data);body=CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString();}
    request(type==JSDIALOGTYPE_PROMPT?"prompt":type==JSDIALOGTYPE_ALERT?"alert":"confirm",origin.ToString(),body,[cb](bool yes,std::string text){cb->Continue(yes,text);}); return true;
  }
  bool OnBeforeUnloadDialog(CefRefPtr<CefBrowser>,const CefString &message,bool,CefRefPtr<CefJSDialogCallback> cb) override {
    CefRefPtr<Client> keep(this);request("confirm","Leave page?",message.ToString(),[keep,cb](bool yes,std::string text){if(!yes && keep->close_requested){keep->close_requested=false;keep->event("close-cancelled","");}cb->Continue(yes,text);}); return true;
  }
  bool OnFileDialog(CefRefPtr<CefBrowser>,FileDialogMode mode,const CefString &title,const CefString &initial,const std::vector<CefString>& filters,const std::vector<CefString>&,const std::vector<CefString>&,CefRefPtr<CefFileDialogCallback> cb) override {
    auto descriptor=CefDictionaryValue::Create();descriptor->SetInt("mode",mode);descriptor->SetString("initial",initial);
    auto list=CefListValue::Create();for(size_t i=0;i<filters.size();i++)list->SetString(i,filters[i]);descriptor->SetList("filters",list);auto value=CefValue::Create();value->SetDictionary(descriptor);
    request("file",title.ToString(),CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString(),[cb](bool yes,std::string text){
      auto value=CefParseJSON(text,JSON_PARSER_RFC);if(!yes || !value || value->GetType()!=VTYPE_LIST){cb->Cancel();return;}
      auto list=value->GetList();std::vector<CefString> paths;for(size_t i=0;i<list->GetSize();i++)if(list->GetType(i)==VTYPE_STRING)paths.push_back(list->GetString(i));
      if(paths.empty())cb->Cancel();else cb->Continue(paths);
    });return true;
  }
  bool GetAuthCredentials(CefRefPtr<CefBrowser>,const CefString &origin,bool,const CefString&,int,const CefString &realm,const CefString&,CefRefPtr<CefAuthCallback> callback) override {
    CefRefPtr<Client> keep(this);std::string site=origin.ToString(),message=realm.ToString();
    ui([keep,site,message,callback]{keep->request("http-auth",site,message,[callback](bool yes,std::string text){
      auto data=CefParseJSON(text,JSON_PARSER_RFC);if(!yes || !data || data->GetType()!=VTYPE_DICTIONARY){callback->Cancel();return;}
      auto fields=data->GetDictionary();callback->Continue(fields->GetString("username"),fields->GetString("password"));
    });});return true;
  }
  void OnResetDialogState(CefRefPtr<CefBrowser>) override {
    std::vector<int> tokens;for(auto &[id,kind]:reply_kinds)if(kind=="alert" || kind=="confirm" || kind=="prompt")tokens.push_back(id);
    for(auto id:tokens){reply(id,false,"");event("request-dismissed",std::to_string(id));}
  }
  bool OnBeforeDownload(CefRefPtr<CefBrowser>,CefRefPtr<CefDownloadItem> item,const CefString &name,CefRefPtr<CefBeforeDownloadCallback> cb) override {
    request("download",item->GetURL().ToString(),name.ToString(),[cb](bool yes,std::string path){if(yes) cb->Continue(path,false);}); return true;
  }
  void OnDownloadUpdated(CefRefPtr<CefBrowser>,CefRefPtr<CefDownloadItem> d,CefRefPtr<CefDownloadItemCallback> callback) override {
    if(d->IsInProgress())downloads[d->GetId()]=callback;else downloads.erase(d->GetId());
    auto item=CefDictionaryValue::Create();item->SetInt("id",d->GetId());item->SetString("source",d->GetURL());item->SetString("path",d->GetFullPath());
    auto reason=d->GetInterruptReason();
    bool blocked=reason==CEF_DOWNLOAD_INTERRUPT_REASON_FILE_VIRUS_INFECTED || reason==CEF_DOWNLOAD_INTERRUPT_REASON_FILE_BLOCKED;
    item->SetString("status",d->IsComplete()?"complete":d->IsCanceled()?"cancelled":d->IsInterrupted()?(blocked?"security-blocked":reason==CEF_DOWNLOAD_INTERRUPT_REASON_FILE_SECURITY_CHECK_FAILED?"security-check-failed":"interrupted"):d->IsPaused()?"paused":"active");
    item->SetDouble("received",d->GetReceivedBytes());item->SetDouble("total",d->GetTotalBytes());item->SetDouble("speed",d->GetCurrentSpeed());item->SetString("error",d->IsInterrupted()?std::to_string(d->GetInterruptReason()):"");auto value=CefValue::Create();value->SetDictionary(item);event("download",CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString());
  }
  bool OnShowPermissionPrompt(CefRefPtr<CefBrowser>,uint64_t prompt_id,const CefString &origin,uint32_t permissions,CefRefPtr<CefPermissionPromptCallback> cb) override {
    std::vector<std::pair<uint32_t,std::string>> supported={{CEF_PERMISSION_TYPE_CAMERA_STREAM,"camera"},{CEF_PERMISSION_TYPE_MIC_STREAM,"microphone"},{CEF_PERMISSION_TYPE_GEOLOCATION,"location"},{CEF_PERMISSION_TYPE_NOTIFICATIONS,"notifications"},{CEF_PERMISSION_TYPE_CLIPBOARD,"clipboard"},{CEF_PERMISSION_TYPE_MULTIPLE_DOWNLOADS,"multiple downloads"},{CEF_PERMISSION_TYPE_POINTER_LOCK,"pointer lock"},{CEF_PERMISSION_TYPE_KEYBOARD_LOCK,"keyboard lock"},{CEF_PERMISSION_TYPE_STORAGE_ACCESS,"storage access"},{CEF_PERMISSION_TYPE_TOP_LEVEL_STORAGE_ACCESS,"storage access"},{CEF_PERMISSION_TYPE_LOCAL_FONTS,"local fonts"}};
    uint32_t known=0;std::string names;for(auto &[mask,name]:supported)if(permissions&mask){known|=mask;if(!names.empty())names+=",";names+=name;}
    if((permissions&~known)!=0 || names.empty()){cb->Continue(CEF_PERMISSION_RESULT_DENY);return true;}
    std::string site=origin;permission_prompts[prompt_id]=request("permission:"+names,site,"This website wants access to "+names,[this,cb,site](bool yes,std::string choice){if(yes && choice=="once")temporary_permission_origins.insert(site);cb->Continue(yes?CEF_PERMISSION_RESULT_ACCEPT:choice=="persistent"?CEF_PERMISSION_RESULT_DENY:CEF_PERMISSION_RESULT_DISMISS);});return true;
  }
  void OnDismissPermissionPrompt(CefRefPtr<CefBrowser>,uint64_t prompt_id,cef_permission_request_result_t) override {
    auto it=permission_prompts.find(prompt_id);if(it==permission_prompts.end())return;
    int id=it->second;permission_prompts.erase(it);replies.erase(id);reply_kinds.erase(id);event("request-dismissed",std::to_string(id));
  }
  bool OnRequestMediaAccessPermission(CefRefPtr<CefBrowser>,CefRefPtr<CefFrame>,const CefString &origin,uint32_t mask,CefRefPtr<CefMediaAccessCallback> callback) override {
    uint32_t devices=CEF_MEDIA_PERMISSION_DEVICE_AUDIO_CAPTURE|CEF_MEDIA_PERMISSION_DEVICE_VIDEO_CAPTURE;
    if(mask&~devices){callback->Cancel();return true;}std::string kinds;
    if(mask&CEF_MEDIA_PERMISSION_DEVICE_AUDIO_CAPTURE)kinds="microphone";
    if(mask&CEF_MEDIA_PERMISSION_DEVICE_VIDEO_CAPTURE){if(!kinds.empty())kinds+=",";kinds+="camera";}
    request("permission:"+kinds,origin.ToString(),"This website wants to use your "+kinds,[callback,mask](bool yes,std::string){if(yes)callback->Continue(mask);else callback->Cancel();});return true;
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
class CookieReady : public CefCompletionCallback {
 public:
  CefRefPtr<CefRequestContext> context;std::function<void(CefRefPtr<CefCookieManager>)> action;
  CookieReady(CefRefPtr<CefRequestContext> context,std::function<void(CefRefPtr<CefCookieManager>)> action):context(context),action(std::move(action)){}
  void OnComplete() override {action(context->GetCookieManager(nullptr));}
 private: IMPLEMENT_REFCOUNTING(CookieReady);
};
void cookies_ready(CefRefPtr<Client> client,std::function<void(CefRefPtr<CefCookieManager>)> action){if(client->context)client->context->GetCookieManager(new CookieReady(client->context,std::move(action)));}
class CookieSet : public CefSetCookieCallback {
 public: CefRefPtr<Client> client; explicit CookieSet(CefRefPtr<Client> c):client(c) {}
  void OnComplete(bool ok) override { client->event("cookie-set",ok?"1":"0"); }
 private: IMPLEMENT_REFCOUNTING(CookieSet);
};
class Source : public CefStringVisitor {
 public: CefRefPtr<Client> client;std::string kind;explicit Source(CefRefPtr<Client> c,std::string kind="source"):client(c),kind(std::move(kind)){}
  void Visit(const CefString &html) override {auto text=html.ToString();if(text.size()>4*1024*1024)text.clear();client->event(kind,text);}
 private: IMPLEMENT_REFCOUNTING(Source);
};
class Image : public CefDownloadImageCallback {
 public:CefRefPtr<Client> client;std::string tag;Image(CefRefPtr<Client> c,std::string tag):client(c),tag(std::move(tag)){}
  void OnDownloadImageFinished(const CefString&,int status,CefRefPtr<CefImage> image) override {
    std::string encoded;
    int limit=tag=="copy-image"?4096:512;
    if((status==200 || (tag=="copy-image" && status==0)) && image && !image->IsEmpty() && image->GetWidth()<=limit && image->GetHeight()<=limit){
      int width,height;auto png=image->GetAsPNG(1,true,width,height);if(png && png->GetSize()<=(tag=="copy-image"?32:2)*1024*1024){std::vector<uint8_t> bytes(png->GetSize());png->GetData(bytes.data(),bytes.size(),0);gchar *data=g_base64_encode(bytes.data(),bytes.size());encoded=data;g_free(data);}
    }client->event("image:"+tag,encoded);
  }
 private:IMPLEMENT_REFCOUNTING(Image);
};
CefRefPtr<CefDownloadImageCallback> image_callback(CefRefPtr<Client> client,std::string tag){return new Image(client,std::move(tag));}
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
  void OnComplete(int n) override { client->event("cookies-cleared",std::to_string(n));client->event("operation-complete","clear-browser-cookies"); }
 private: IMPLEMENT_REFCOUNTING(Deleted);
};
class CacheCleared : public CefCompletionCallback {
 public: CefRefPtr<Client> client;explicit CacheCleared(CefRefPtr<Client> c):client(c){}
  void OnComplete() override {client->event("operation-complete","clear-http-cache");}
 private: IMPLEMENT_REFCOUNTING(CacheCleared);
};
class App : public CefApp, public CefBrowserProcessHandler, public CefResourceBundleHandler {
 public:
  std::string display_name=g_getenv("MAJORIS_CEF_DISPLAY_NAME")?g_getenv("MAJORIS_CEF_DISPLAY_NAME"):"Majoris Browser";
  CefRefPtr<CefResourceBundleHandler> GetResourceBundleHandler() override {return this;}
  bool GetLocalizedString(int id,CefString &value) override {if(id!=IDS_PRODUCT_NAME && id!=IDS_SHORT_PRODUCT_NAME)return false;value=display_name;return true;}
  bool GetDataResource(int,void*&,size_t&) override {return false;}
  bool GetDataResourceForScale(int,ScaleFactor,void*&,size_t&) override {return false;}
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override {return this;}
  void OnContextInitialized() override {g_message("CEF: browser context ready");}
  void OnBeforeCommandLineProcessing(const CefString&,CefRefPtr<CefCommandLine> command) override {
    command->AppendSwitch("no-first-run");command->AppendSwitch("no-default-browser-check");
    if(g_getenv("MAJORIS_CEF_TEST_HEADLESS")){command->AppendSwitchWithValue("ozone-platform","headless");command->AppendSwitch("disable-gpu");}
    // Disposable integration fixtures must not open a desktop keyring prompt.
    // Credential tests still exercise libsecret against their own unlocked service.
    if(g_getenv("MAJORIS_CEF_TEST_BASIC_STORE"))command->AppendSwitchWithValue("password-store","basic");
    if(g_getenv("MAJORIS_CEF_DISABLE_GPU"))command->AppendSwitch("disable-gpu");
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
  signals[3]=g_signal_new("popup",G_TYPE_FROM_CLASS(klass),G_SIGNAL_RUN_LAST,0,nullptr,nullptr,nullptr,G_TYPE_NONE,4,MC_TYPE_VIEW,G_TYPE_BOOLEAN,G_TYPE_STRING,G_TYPE_BOOLEAN);
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
  if(!g_path_is_absolute(helper) || !g_file_test(helper,G_FILE_TEST_IS_EXECUTABLE)){g_set_error_literal(error,g_quark_from_static_string("majoris-cef"),4,"CEF subprocess helper is missing or not executable");return false;}
  profile_lock=majoris_profile_acquire(root,error);if(profile_lock<0)return false;
  g_message("CEF: initializing %s",CEF_VERSION);
  cef_api_hash(CEF_API_VERSION,0);
  g_message("CEF: API selected");
  char program[]="majoris-browser";char *argv[]={program,nullptr};
  CefMainArgs args(1,argv); CefSettings settings;
  int process_result=CefExecuteProcess(args,nullptr,nullptr);
  if(process_result>=0){majoris_profile_release(profile_lock);profile_lock=-1;g_set_error_literal(error,g_quark_from_static_string("majoris-cef"),2,"Unexpected subprocess invocation");return false;}
  settings.multi_threaded_message_loop=true;settings.windowless_rendering_enabled=true;
  settings.no_sandbox=false;settings.command_line_args_disabled=true;
  settings.persist_session_cookies=true;
  CefString(&settings.root_cache_path)=root;
  CefString(&settings.browser_subprocess_path)=helper;
  CefString(&settings.resources_dir_path)=resources;
  CefString(&settings.locales_dir_path)=std::string(resources)+"/locales";
  CefString(&settings.user_agent)=user_agent();
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
const char *mc_runtime_version(void) {static const std::string version=std::to_string(cef_version_info(0))+"."+std::to_string(cef_version_info(1))+"."+std::to_string(cef_version_info(2))+" / Chromium "+chrome_version();return version.c_str();}
McView *mc_view_new(const char *profile,gboolean ephemeral,const char *url,const char *scope) {
  return mc_view_new_with_permissions(profile,ephemeral,url,scope,"[]");
}
McView *mc_view_new_with_permissions(const char *profile,gboolean ephemeral,const char *url,const char *scope,const char *permissions) {
  return mc_view_new_with_security(profile,ephemeral,url,scope,permissions,false);
}
McView *mc_view_new_with_security(const char *profile,gboolean ephemeral,const char *url,const char *scope,const char *permissions,gboolean threat_checks) {
  auto *v=MC_VIEW(g_object_new(MC_TYPE_VIEW,nullptr));
  if(!ephemeral && g_mkdir_with_parents(profile,0700)!=0){g_object_unref(v);return nullptr;}
  CefRefPtr<Client> c=new Client(v,scope); v->state->client=c;
  c->set_permissions(permissions);
  c->threat_checks=threat_checks;
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
void mc_view_set_permissions(McView *v,const char *permissions){auto c=v->state->client;std::string text=permissions;ui([c,text]{if(!c->closing){c->set_permissions(text);c->event("permissions-applied","");}});}
void mc_view_close(McView *v) { auto c=v->state->client; if(c) ui([c]{c->closing=true; if(c->browser) c->browser->GetHost()->CloseBrowser(true);}); }
void mc_view_request_close(McView *v) {auto c=v->state->client;if(c)ui([c]{if(c->closing || c->close_requested)return;c->close_requested=true;if(c->browser)c->browser->GetHost()->CloseBrowser(false);});}
void mc_view_drag_end(McView *v,int x,int y,int operation){auto c=v->state->client;ui([c,x,y,operation]{c->end_drag(x,y,operation);});}
void mc_view_set_accessibility(McView *v,gboolean enabled){auto c=v->state->client;ui([c,enabled]{c->accessibility_enabled=enabled;if(c->browser)c->browser->GetHost()->SetAccessibilityState(enabled?STATE_ENABLED:STATE_DISABLED);});}
void mc_view_set_threat_checks(McView *v,gboolean enabled){v->state->client->threat_checks=enabled;}
void mc_view_load(McView *v,const char *url) { auto c=v->state->client; std::string s=url; ui([c,s]{if(c->browser)c->browser->GetMainFrame()->LoadURL(s);}); }
void mc_view_resize(McView *v,int w,int h,double s) { auto c=v->state->client; ui([c,w,h,s]{c->width=std::clamp(w,1,16384); c->height=std::clamp(h,1,16384); c->scale=std::isfinite(s)?std::clamp(s,0.5,4.0):1; if(c->browser){c->browser->GetHost()->NotifyScreenInfoChanged(); c->browser->GetHost()->WasResized();}}); }
void mc_view_focus(McView *v,gboolean focus) { auto c=v->state->client; ui([c,focus]{if(c->browser)c->browser->GetHost()->SetFocus(focus);}); }
void mc_view_reply(McView *v,int token,gboolean yes,const char *text) {auto c=v->state->client; std::string s=text; ui([c,token,yes,s]{c->reply(token,yes,s);});}
void mc_view_pointer(McView *v,int kind,int x,int y,int button,int modifiers,int dx,int dy) {
  auto c=v->state->client; ui([=]{if(!c->browser)return; CefMouseEvent e; e.x=x;e.y=y;e.modifiers=modifiers;
    auto h=c->browser->GetHost();
    if(kind==0 || kind==4)h->SendMouseMoveEvent(e,kind==4);
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
    else if(s=="print"){if(c->gtk_print_pending)c->event("operation-error","print-busy");else h->Print();}
    else if(s=="undo")b->GetFocusedFrame()->Undo();else if(s=="redo")b->GetFocusedFrame()->Redo();
    else if(s.starts_with("spell:") && s.size()<512)h->ReplaceMisspelling(s.substr(6));
    else if(s.starts_with("context-media:"))c->context_media(s.substr(14));
    else if(s=="copy-context-image" && !c->context_source.empty())h->DownloadImage(c->context_source,false,4096,false,image_callback(c,"copy-image"));
    else if(s=="view-source")f->GetSource(new Source(c,"source-view"));
    else if(s=="inspect-context"){CefWindowInfo wi;wi.runtime_style=CEF_RUNTIME_STYLE_ALLOY;CefBrowserSettings bs;h->ShowDevTools(wi,nullptr,bs,CefPoint(c->context_x,c->context_y));}
    else if(s=="save-pdf"){auto args=CefDictionaryValue::Create();args->SetBool("printBackground",true);c->protocol("Page.printToPDF",args,s);}
    else if(s=="save-page"){auto args=CefDictionaryValue::Create();args->SetString("format","mhtml");c->protocol("Page.captureSnapshot",args,s);}
    // AlloyBrowserHostImpl::IsPictureInPictureSupported returns false for OSR.
    else if(s=="picture-in-picture")c->event("operation-error","picture-in-picture");
    else if(s=="auth-cancel")c->revoke_auth("user-cancelled");
    else if(s.starts_with("proxy:")){
      std::string address=s.substr(6);auto settings=CefDictionaryValue::Create();settings->SetString("mode",address.empty()?"system":"fixed_servers");if(!address.empty())settings->SetString("server",address);auto value=CefValue::Create();value->SetDictionary(settings);CefString error;if(c->context->SetPreference("proxy",value,error))c->event("proxy-applied","");else c->event("operation-error","Proxy setting: "+error.ToString());
    }
    else if(s=="copy")b->GetFocusedFrame()->Copy();else if(s=="cut")b->GetFocusedFrame()->Cut();else if(s=="paste")b->GetFocusedFrame()->Paste();else if(s=="select-all")b->GetFocusedFrame()->SelectAll();else if(s=="source")f->ViewSource();
    else if(s=="mute"){h->SetAudioMuted(!h->IsAudioMuted());c->event("muted",h->IsAudioMuted()?"1":"0");}
    else if(s.starts_with("zoom:"))h->SetZoomLevel(g_ascii_strtod(s.c_str()+5,nullptr));
    else if(s.starts_with("privacy:")){
      auto fields=g_strsplit(s.c_str(),":",3);bool cookie=fields[1] && std::string(fields[1])=="1",https=fields[2] && std::string(fields[2])=="1";g_strfreev(fields);CefString error;
      auto cookies=CefValue::Create();cookies->SetInt(cookie?1:0);auto upgrades=CefValue::Create();upgrades->SetBool(https);
      bool ok=c->context->SetPreference("profile.cookie_controls_mode",cookies,error);if(!ok)c->event("operation-error","Third-party cookie setting: "+error.ToString());
      bool upgraded=c->context->SetPreference("https_only_mode_enabled",upgrades,error);if(!upgraded)c->event("operation-error","HTTPS upgrade setting: "+error.ToString());
      if(ok && upgraded)c->event("privacy-applied","");
    }
    else if(s=="devtools"){CefWindowInfo wi;wi.runtime_style=CEF_RUNTIME_STYLE_ALLOY;CefBrowserSettings bs;h->ShowDevTools(wi,nullptr,bs,CefPoint());}
    else if(s.rfind("find:",0)==0)h->Find(s.substr(5),true,false,false);
    else if(s=="find-stop")h->StopFinding(true);
    else if(s=="source-metadata")f->GetSource(new Source(c));
    else if(s.starts_with("download:"))h->StartDownload(s.substr(9));
    else if(s.rfind("download-",0)==0){auto colon=s.find(':');if(colon!=std::string::npos){auto id=static_cast<uint32_t>(g_ascii_strtoull(s.c_str()+colon+1,nullptr,10));auto it=c->downloads.find(id);if(it!=c->downloads.end()){if(s.starts_with("download-cancel:"))it->second->Cancel();else if(s.starts_with("download-pause:"))it->second->Pause();else if(s.starts_with("download-resume:"))it->second->Resume();}}}
    else if(s=="tasks-start"){++c->task_observers;if(!c->task_manager)c->task_manager=CefTaskManager::GetTaskManager();}
    else if(s=="tasks-stop"){if(c->task_observers>0)--c->task_observers;if(!c->task_observers)c->task_manager=nullptr;}
    else if(s=="tasks"){
      if(!c->task_manager)c->task_manager=CefTaskManager::GetTaskManager();auto manager=c->task_manager;CefTaskManager::TaskIdList ids;std::string data;
      if(manager && manager->GetTaskIdsList(ids))for(auto id:ids){CefTaskInfo info;if(manager->GetTaskInfo(id,info)){
        gchar *title=g_strescape(CefString(&info.title).ToString().c_str(),nullptr);
        data+=std::to_string(id)+"\t"+std::to_string(info.type)+"\t"+std::to_string(info.cpu_usage)+"\t"+std::to_string(info.memory)+"\t"+std::to_string(info.is_killable)+"\t"+title+"\t"+std::to_string(info.gpu_memory)+"\t"+std::to_string(info.is_gpu_memory_inflated)+"\t"+(manager->GetTaskIdForBrowserId(c->browser->GetIdentifier())==id?"1":"0")+"\n";g_free(title);
      }}c->event("tasks",data);
    }else if(s.rfind("kill-task:",0)==0){if(!c->task_manager)c->task_manager=CefTaskManager::GetTaskManager();if(!c->task_manager || !c->task_manager->KillTask(g_ascii_strtoll(s.c_str()+10,nullptr,10)))c->event("operation-error","kill-task");}
  });
}
void mc_view_clear_cookies(McView *v) {auto c=v->state->client;ui([c]{cookies_ready(c,[c](auto manager){if(!manager->DeleteCookies("","",new Deleted(c)))c->event("operation-error","clear-cookies");});});}
void mc_view_clear_http_cache(McView *v){auto c=v->state->client;ui([c]{if(c->context && !c->closing)c->context->ClearHttpCache(new CacheCleared(c));else c->event("operation-error","clear-http-cache");});}
void mc_view_clear_site_cookies(McView *v,const char *url){auto c=v->state->client;std::string target=url;ui([c,target]{c->clear_site_cookies(target);});}
void mc_view_cookie_inventory(McView *v){auto c=v->state->client;ui([c]{c->protocol("Network.getAllCookies",nullptr,"cookie-inventory");});}
void mc_view_set_partitioned_cookie(McView *v,const char *url,const char *name,const char *value,const char *top_level_site){auto c=v->state->client;std::string target=url,key=name,content=value,site=top_level_site;ui([=]{auto args=CefDictionaryValue::Create();args->SetString("url",target);args->SetString("name",key);args->SetString("value",content);args->SetBool("secure",true);args->SetString("sameSite","None");auto partition=CefDictionaryValue::Create();partition->SetString("topLevelSite",schemeful_site(site));partition->SetBool("hasCrossSiteAncestor",false);args->SetDictionary("partitionKey",partition);c->protocol("Network.setCookie",args,"partition-cookie-set");});}void mc_view_clear_site_data(McView *v,const char *url){auto c=v->state->client;std::string target=url;ui([c,target]{
  CefURLParts parts;if(!CefParseURL(target,parts))return;
  std::string scheme=CefString(&parts.scheme);if(scheme!="https" && scheme!="http")return;
  if(!c->browser || Client::origin(c->browser->GetMainFrame()->GetURL())!=Client::origin(target)){c->event("operation-error","clear-site-data");return;}
  c->protocol("Page.getFrameTree",nullptr,"site-storage-frame|"+Client::origin(target));
  c->clear_site_cookies(target);
});}
void mc_view_ime(McView *v,const char *text,int selection,gboolean commit){auto c=v->state->client;std::string value=text;ui([c,value,selection,commit]{
  if(!c->browser || c->closing)return;auto host=c->browser->GetHost();CefString utf16=value;
  CefRange unspecified(UINT32_MAX,UINT32_MAX);
  if(commit)host->ImeCommitText(utf16,unspecified,0);
  else if(value.empty())host->ImeCancelComposition();
  else {CefCompositionUnderline line;line.range=CefRange(0,utf16.length());line.color=0xff000000;line.background_color=0;line.thick=false;host->ImeSetComposition(utf16,{line},unspecified,CefRange(selection,selection));}
});}
void mc_view_set_cookie(McView *v,const char *url,const char *name,const char *value) {
  auto c=v->state->client;std::string u=url,n=name,s=value;
  ui([c,u,n,s]{cookies_ready(c,[c,u,n,s](auto manager){CefCookie cookie;CefString(&cookie.name)=n;CefString(&cookie.value)=s;CefString(&cookie.path)="/";if(!manager->SetCookie(u,cookie,new CookieSet(c)))c->event("operation-error","set-cookie");});});
}
void mc_view_set_cookie_details(McView *v,const char *url,const char *name,const char *value,const char *domain,const char *path,gboolean secure,gboolean http_only){
  auto c=v->state->client;std::string u=url,n=name,s=value,d=domain,p=path;ui([c,u,n,s,d,p,secure,http_only]{cookies_ready(c,[c,u,n,s,d,p,secure,http_only](auto manager){CefCookie cookie;CefString(&cookie.name)=n;CefString(&cookie.value)=s;CefString(&cookie.domain)=d;CefString(&cookie.path)=p;cookie.secure=secure;cookie.httponly=http_only;if(!manager->SetCookie(u,cookie,new CookieSet(c)))c->event("operation-error","set-cookie");});});
}
void mc_view_get_cookies(McView *v,const char *url) {auto c=v->state->client;std::string u=url;ui([c,u]{cookies_ready(c,[c,u](auto manager){if(!manager->VisitUrlCookies(u,true,new Cookies(c)))c->event("operation-error","get-cookies");});});}
void mc_view_allow_auth_for(McView *v,const char *url,int seconds){auto c=v->state->client;std::string target=url;ui([c,target,seconds]{c->allow_auth(target,seconds);});}
void mc_view_allow_auth(McView *v,const char *url){auto c=v->state->client;std::string target=url;ui([c,target]{c->allow_auth(target);});}
gboolean mc_view_is_auth_popup(McView *v){return v->state->auth_popup.load();}
void mc_view_autofill(McView *v,const char *origin,const char *username,const char *password){
  auto c=v->state->client;std::string site=origin,user=username,secret=password;
  ui([c,site,user,secret]{
    if(!c->secure_fill(site) || user.size()>4096 || secret.size()>16384 || c->credential_contexts.empty()){c->event("credential-fill-refused","The secure current origin does not match the saved login");return;}
    auto data=CefDictionaryValue::Create();data->SetString("username",user);data->SetString("password",secret);data->SetString("origin",AuthFlow::origin(site));auto value=CefValue::Create();value->SetDictionary(data);
    std::string script="(()=>{const v="+CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString()+";if(globalThis.origin!==v.origin||location.origin!==v.origin)return 0;return "+credential_fill+";})()";
    uint64_t batch=++c->fill_serial;c->fill_batches[batch]={static_cast<int>(c->credential_contexts.size()),0};
    for(auto &[id,context]:c->credential_contexts){auto args=CefDictionaryValue::Create();args->SetInt("contextId",id);args->SetString("expression",script);args->SetBool("returnByValue",true);c->protocol("Runtime.evaluate",args,"autofill|"+std::to_string(batch));}
  });
}
void mc_view_fill_address(McView *v,const char *origin,const char *fields){auto c=v->state->client;std::string site=origin,data=fields;ui([c,site,data]{
  if(!c->secure_fill(site) || data.size()>16384){c->event("address-fill-refused","0");return;}
  auto parsed=CefParseJSON(data,JSON_PARSER_RFC);if(!parsed || parsed->GetType()!=VTYPE_DICTIONARY)return;auto safe=CefDictionaryValue::Create();auto input=parsed->GetDictionary();int selected=input->GetInt("__majorisContext");
  for(auto key:{"name","given-name","family-name","organization","street-address","address-line1","address-line2","address-line3","address-level2","address-level1","postal-code","country","country-name","tel","email"})if(input->GetType(key)==VTYPE_STRING)safe->SetString(key,input->GetString(key));safe->SetString("__majorisOrigin",AuthFlow::origin(site));auto value=CefValue::Create();value->SetDictionary(safe);
  std::string script="(()=>{const fields="+CefWriteJSON(value,JSON_WRITER_DEFAULT).ToString()+";if(globalThis.origin!==fields.__majorisOrigin||location.origin!==fields.__majorisOrigin)return 0;return "+address_fill+";})()";
  for(auto &[id,context]:c->credential_contexts)if((selected && selected==id) || (!selected && context.main)){auto args=CefDictionaryValue::Create();args->SetInt("contextId",id);args->SetString("expression",script);args->SetBool("returnByValue",true);c->protocol("Runtime.evaluate",args,"address-fill");return;}c->event("address-fill-refused","0");
});}
void mc_view_fetch_manifest(McView *v,const char *url){auto c=v->state->client;std::string target=url;ui([c,target]{
  if(!c->context)return;
  GError *error=nullptr;GUri *uri=g_uri_parse(target.c_str(),G_URI_FLAGS_NONE,&error);g_clear_error(&error);
  bool valid=uri && g_uri_get_host(uri) && !g_uri_get_userinfo(uri) && (g_strcmp0(g_uri_get_scheme(uri),"https")==0 || g_strcmp0(g_uri_get_scheme(uri),"http")==0);if(uri)g_uri_unref(uri);
  if(!valid){c->event("manifest","");return;}
  auto request=CefRequest::Create();request->SetURL(target);request->SetMethod("GET");c->manifest_request=CefURLRequest::Create(request,new Manifest(c),c->context);
});}
void mc_view_fetch_image(McView *v,const char *url,const char *tag){auto c=v->state->client;std::string target=url,label=tag;ui([c,target,label]{CefURLParts parts;if(!c->browser || !CefParseURL(target,parts))return;std::string scheme=CefString(&parts.scheme);if(scheme=="http" || scheme=="https")c->browser->GetHost()->DownloadImage(target,false,256,false,image_callback(c,label));});}
void mc_view_evaluate(McView *v,const char *expression){auto c=v->state->client;std::string script=expression;ui([c,script]{auto params=CefDictionaryValue::Create();params->SetString("expression",script);params->SetBool("returnByValue",true);params->SetBool("awaitPromise",true);c->protocol("Runtime.evaluate",params,"evaluate");});}
void mc_view_drop(McView *v,const char *text,const char *files,int x,int y){auto c=v->state->client;std::string content=text,paths=files;ui([c,content,paths,x,y]{
  if(!c->browser || c->closing || content.size()>8*1024*1024 || paths.size()>1024*1024)return;
  auto drag=CefDragData::Create();if(!content.empty())drag->SetFragmentText(content);
  auto list=CefParseJSON(paths,JSON_PARSER_RFC);if(list && list->GetType()==VTYPE_LIST){auto items=list->GetList();for(size_t i=0;i<items->GetSize() && i<100;i++){auto path=items->GetString(i).ToString();if(g_path_is_absolute(path.c_str()) && g_file_test(path.c_str(),G_FILE_TEST_IS_REGULAR))drag->AddFile(path,"");}}
  CefMouseEvent event;event.x=x;event.y=y;auto host=c->browser->GetHost();host->DragTargetDragEnter(drag,event,DRAG_OPERATION_COPY);host->DragTargetDragOver(event,DRAG_OPERATION_COPY);host->DragTargetDrop(event);
});}
void mc_view_drag_target(McView *v,int phase,const char *text,const char *files,int x,int y){auto c=v->state->client;std::string content=text,paths=files;ui([c,phase,content,paths,x,y]{
  if(!c->browser || c->closing || content.size()>8*1024*1024 || paths.size()>1024*1024)return;auto host=c->browser->GetHost();CefMouseEvent event;event.x=x;event.y=y;
  if(phase==0){
    if(c->target_drag_active)host->DragTargetDragLeave();c->target_drag_active=true;c->target_drag_operation=DRAG_OPERATION_NONE;
    auto data=CefDragData::Create();if(!content.empty()){data->SetFragmentText(content);CefURLParts url;if(CefParseURL(content,url) && (CefString(&url.scheme)=="http" || CefString(&url.scheme)=="https"))data->SetLinkURL(content);}
    auto parsed=CefParseJSON(paths,JSON_PARSER_RFC);if(parsed && parsed->GetType()==VTYPE_LIST){auto list=parsed->GetList();for(size_t i=0;i<list->GetSize() && i<100;i++){auto path=list->GetString(i).ToString();if(g_path_is_absolute(path.c_str()) && g_file_test(path.c_str(),G_FILE_TEST_IS_REGULAR))data->AddFile(path,"");}}
    data->ResetFileContents();event.modifiers=EVENTFLAG_LEFT_MOUSE_BUTTON;host->DragTargetDragEnter(data,event,DRAG_OPERATION_COPY);host->DragTargetDragOver(event,DRAG_OPERATION_COPY);
  }else if(c->target_drag_active){
    if(phase==1){event.modifiers=EVENTFLAG_LEFT_MOUSE_BUTTON;host->DragTargetDragOver(event,DRAG_OPERATION_COPY);}
    else{if(phase==2 && c->target_drag_operation!=DRAG_OPERATION_NONE)host->DragTargetDrop(event);else host->DragTargetDragLeave();c->target_drag_active=false;c->target_drag_operation=DRAG_OPERATION_NONE;}
  }
});}
