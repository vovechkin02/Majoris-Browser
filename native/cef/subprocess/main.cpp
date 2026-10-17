#include "include/cef_app.h"
#include "include/cef_api_hash.h"
int main(int argc,char **argv) {
  cef_api_hash(CEF_API_VERSION,0);
  CefMainArgs args(argc,argv);
  return CefExecuteProcess(args,nullptr,nullptr);
}
