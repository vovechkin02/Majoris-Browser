#pragma once
#include <glib.h>
#include <functional>
#include <map>
#include <memory>
#include <set>
#include <string>
#include "include/cef_parser.h"

struct AuthFlow {
  std::string id,app_id,initiator,return_uri,state;
  std::set<std::string> origins;
  gint64 deadline=0;
  bool active=false;
  AuthFlow(){gchar *uuid=g_uuid_string_random();id=uuid;g_free(uuid);const char *desktop=g_getenv("CHROME_DESKTOP");if(desktop)app_id=desktop;}
  bool alive() const {return active && g_get_monotonic_time()<deadline;}
  static std::string origin(const std::string &url){CefURLParts parts;if(!CefParseURL(url,parts))return {};std::string result=CefString(&parts.origin);if(result.ends_with('/'))result.pop_back();return result;}
  static bool query(GUri *uri,std::map<std::string,std::string> &result){
    const char *text=g_uri_get_query(uri);if(!text)return true;
    GUriParamsIter iterator;g_uri_params_iter_init(&iterator,text,-1,"&",G_URI_PARAMS_WWW_FORM);GError *error=nullptr;gchar *key=nullptr,*value=nullptr;
    while(g_uri_params_iter_next(&iterator,&key,&value,&error)){std::string name=key;bool duplicate=result.contains(name);result[name]=value?value:"";g_free(key);g_free(value);if(duplicate)return false;}
    if(error){g_error_free(error);return false;}return true;
  }
  static bool candidate(const std::string &url,const std::function<bool(const std::string&)> &in_scope,std::string &back,std::string &state){
    if(url.size()>16384)return false;GError *error=nullptr;GUri *uri=g_uri_parse(url.c_str(),G_URI_FLAGS_NONE,&error);g_clear_error(&error);if(!uri)return false;
    std::map<std::string,std::string> parameters;bool valid=g_strcmp0(g_uri_get_scheme(uri),"https")==0 && !g_uri_get_userinfo(uri) && query(uri,parameters);std::string host=g_uri_get_host(uri)?g_uri_get_host(uri):"";g_uri_unref(uri);if(!valid)return false;
    if(host=="accounts.google.com" && parameters.contains("continue")){back=parameters["continue"];state="";}
    else{
      bool recognized=host=="accounts.google.com" || host=="login.microsoftonline.com" || host=="accounts.spotify.com";
      if(!parameters.contains("redirect_uri") || parameters["client_id"].empty() || parameters["state"].size()<16 || parameters["state"].size()>4096 || (!recognized && parameters["response_type"]!="code"))return false;
      back=parameters["redirect_uri"];state=parameters["state"];
    }
    if(back.size()>4096 || !in_scope(back))return false;
    uri=g_uri_parse(back.c_str(),G_URI_FLAGS_NONE,&error);g_clear_error(&error);valid=uri && !g_uri_get_userinfo(uri) && !g_uri_get_fragment(uri);if(uri)g_uri_unref(uri);return valid;
  }
  bool returned(const std::string &target) const {
    CefURLParts expected,actual;if(!CefParseURL(return_uri,expected) || !CefParseURL(target,actual) || CefString(&expected.origin)!=CefString(&actual.origin) || CefString(&expected.path)!=CefString(&actual.path))return false;
    GError *error=nullptr;GUri *back=g_uri_parse(return_uri.c_str(),G_URI_FLAGS_NONE,&error);g_clear_error(&error);GUri *url=g_uri_parse(target.c_str(),G_URI_FLAGS_NONE,&error);g_clear_error(&error);std::map<std::string,std::string> required,parameters;
    bool valid=back && url && query(back,required) && query(url,parameters);if(back)g_uri_unref(back);if(url)g_uri_unref(url);if(!valid)return false;
    for(auto &[key,value]:required)if(!parameters.contains(key) || parameters[key]!=value)return false;
    return state.empty() || (parameters["state"]==state && (!parameters["code"].empty() || parameters.contains("error")));
  }
};
