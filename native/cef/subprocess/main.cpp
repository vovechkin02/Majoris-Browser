#include "include/cef_app.h"
#include "include/cef_api_hash.h"
#include "include/base/cef_compiler_specific.h"
// Chromium deliberately resets the canary in forked zygote children. Like
// CefExecuteProcess itself, its caller must not check the pre-fork canary.
// Keep this entry point small; all other application code retains hardening.
NO_STACK_PROTECTOR int main(int argc,char **argv) {
  cef_api_hash(CEF_API_VERSION,0);
  CefMainArgs args(argc,argv);
  return CefExecuteProcess(args,nullptr,nullptr);
}
