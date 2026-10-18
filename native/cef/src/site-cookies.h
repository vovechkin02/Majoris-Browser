#pragma once
#include <libpsl.h>
// Schemeful site uses the public suffix list, including private registries.
static std::string schemeful_site(const std::string &url){
  CefURLParts parts;if(!CefParseURL(url,parts))return {};
  std::string scheme=CefString(&parts.scheme),host=CefString(&parts.host);
  if((scheme!="https" && scheme!="http") || host.empty())return {};
  const char *registrable=psl_registrable_domain(psl_builtin(),host.c_str());
  return scheme+"://"+(registrable?registrable:host);
}
