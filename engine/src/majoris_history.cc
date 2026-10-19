// Copyright 2026 Majoris Browser contributors. BSD-style license.
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include "base/base64.h"
#include "base/containers/span.h"
#include "base/json/json_reader.h"
#include "base/json/json_writer.h"
#include "base/pickle.h"
#include "components/version_info/version_info.h"
#include "cef/include/cef_task.h"
#include "cef/include/internal/cef_export.h"
#include "cef/libcef/browser/browser_host_base.h"
#include "components/sessions/content/content_serialized_navigation_builder.h"
#include "components/sessions/core/serialized_navigation_entry.h"
#include "content/public/browser/browser_context.h"
#include "content/public/browser/navigation_controller.h"
#include "content/public/browser/navigation_entry.h"
#include "content/public/browser/web_contents.h"
#include "third_party/blink/public/common/page_state/page_state.h"
#include "third_party/blink/public/common/page_state/page_state_serialization.h"
#include "url/gurl.h"

namespace {
constexpr size_t kMaxHistoryBytes = 4 * 1024 * 1024;
bool SafeURL(const GURL& url) {
  return url.is_valid() && !url.has_username() && !url.has_password() &&
         (url.SchemeIsHTTPOrHTTPS() || url.spec() == "about:blank");
}
bool SafeFrame(const blink::ExplodedFrameState& frame, int depth, int& nodes) {
  if (depth > 32 || ++nodes > 1024 || frame.http_body.request_body ||
      frame.http_body.contains_passwords) return false;
  if (frame.url_string && !SafeURL(GURL(*frame.url_string))) return false;
  for (const auto& child : frame.children)
    if (!SafeFrame(child, depth + 1, nodes)) return false;
  return true;
}
bool SafeState(const std::string& encoded) {
  if (encoded.empty() || encoded.size() > 1024 * 1024) return false;
  blink::ExplodedPageState state;
  int nodes = 0;
  return blink::DecodePageState(encoded, &state) &&
         state.referenced_files.empty() && SafeFrame(state.top, 0, nodes);
}
content::WebContents* PersistentBrowser(int id) {
  if (!CefCurrentlyOn(TID_UI)) return nullptr;
  auto browser = CefBrowserHostBase::GetBrowserForBrowserId(id);
  auto* contents = browser ? browser->GetWebContents() : nullptr;
  if (!contents || contents->GetBrowserContext()->IsOffTheRecord() ||
      contents->GetBrowserContext()->GetPath().empty()) return nullptr;
  return contents;
}
}

extern "C" CEF_EXPORT char* cef_majoris_history_snapshot(int browser_id) {
  auto* contents = PersistentBrowser(browser_id);
  if (!contents) return nullptr;
  auto& controller = contents->GetController();
  int count = controller.GetEntryCount(), selected = controller.GetCurrentEntryIndex();
  if (count < 1 || count > 100 || selected < 0 || selected >= count) return nullptr;
  base::ListValue entries;
  size_t total = 0;
  for (int index = 0; index < count; ++index) {
    auto* entry = controller.GetEntryAtIndex(index);
    if (!entry || entry->GetHasPostData() || !SafeURL(entry->GetURL()) ||
        !SafeURL(entry->GetVirtualURL())) return nullptr;
    auto state = entry->GetPageState();
    if (!SafeState(state.ToEncodedData())) return nullptr;
    auto saved = sessions::ContentSerializedNavigationBuilder::FromNavigationEntry(index, entry);
    saved.set_encoded_page_state(state.RemovePasswordData().ToEncodedData());
    base::Pickle pickle;
    saved.WriteToPickle(1024 * 1024, &pickle);
    total += pickle.size();
    if (total > kMaxHistoryBytes / 2) return nullptr;
    entries.Append(base::Base64Encode(pickle.AsBytes()));
  }
  base::DictValue document;
  document.Set("schema", 1);
  document.Set("chromium", std::string(version_info::GetVersionNumber()));
  document.Set("profile", contents->GetBrowserContext()->GetPath().value());
  document.Set("selected", selected);
  document.Set("selected_url", controller.GetEntryAtIndex(selected)->GetVirtualURL().spec());
  document.Set("entries", std::move(entries));
  auto json = base::WriteJson(document);
  if (!json || json->size() > kMaxHistoryBytes) return nullptr;
  auto* output = static_cast<char*>(std::malloc(json->size() + 1));
  if (output) std::memcpy(output, json->c_str(), json->size() + 1);
  return output;
}

extern "C" CEF_EXPORT void cef_majoris_history_free(void* data) {
  std::free(data);
}

extern "C" CEF_EXPORT int cef_majoris_history_restore(
    int browser_id, const char* data, size_t size) {
  auto* contents = PersistentBrowser(browser_id);
  if (!contents || !data || size == 0 || size > kMaxHistoryBytes) return 0;
  auto& controller = contents->GetController();
  // Chromium creates one initial placeholder even before any navigation.
  // Restore explicitly removes that placeholder; a used controller is refused.
  if (controller.GetEntryCount() != 1 || controller.GetPendingEntry() ||
      !controller.GetLastCommittedEntry() ||
      !controller.GetLastCommittedEntry()->IsInitialEntry()) return 0;
  auto document = base::JSONReader::ReadDict(std::string_view(data, size), base::JSON_PARSE_RFC);
  if (!document || document->FindInt("schema") != 1) return 0;
  const auto* version = document->FindString("chromium");
  const auto* profile = document->FindString("profile");
  const auto* entries = document->FindList("entries");
  auto selected = document->FindInt("selected");
  if (!version || *version != version_info::GetVersionNumber() || !profile ||
      *profile != contents->GetBrowserContext()->GetPath().value() || !entries ||
      entries->empty() || entries->size() > 100 || !selected || *selected < 0 ||
      static_cast<size_t>(*selected) >= entries->size()) return 0;
  std::vector<sessions::SerializedNavigationEntry> saved;
  for (const auto& value : *entries) {
    if (!value.is_string() || value.GetString().size() > 2 * 1024 * 1024) return 0;
    std::string decoded;
    if (!base::Base64Decode(value.GetString(), &decoded) || decoded.size() > 1024 * 1024) return 0;
    auto iterator = base::PickleIterator::WithData(base::as_byte_span(decoded));
    sessions::SerializedNavigationEntry entry;
    if (!entry.ReadFromPickle(&iterator) || entry.has_post_data() ||
        !SafeURL(entry.virtual_url()) || !SafeState(entry.encoded_page_state())) return 0;
    saved.push_back(std::move(entry));
  }
  auto restored = sessions::ContentSerializedNavigationBuilder::ToNavigationEntries(
      saved, contents->GetBrowserContext());
  if (restored.size() != saved.size()) return 0;
  for (const auto& entry : restored)
    if (!entry || entry->GetHasPostData() || !SafeURL(entry->GetURL())) return 0;
  controller.Restore(*selected, content::RestoreType::kRestored, &restored);
  controller.LoadIfNecessary();  // Only the selected entry; never replay the list.
  return 1;
}
