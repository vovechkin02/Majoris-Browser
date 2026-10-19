// Copyright 2026 Majoris Browser contributors.
// Use of this source code is governed by a BSD-style license.
#include <stdint.h>
#include <algorithm>
#include <cstring>
#include <map>
#include <memory>
#include <string>
#include "base/command_line.h"
#include "base/unguessable_token.h"
#include "base/json/values_util.h"
#include "base/strings/string_util.h"
#include "base/values.h"
#include "build/build_config.h"
#include "cef/include/cef_task.h"
#include "cef/include/cef_task_manager.h"
#include "cef/include/internal/cef_export.h"
#include "cef/libcef/browser/browser_host_base.h"
#include "cef/libcef/browser/majoris_runtime_internal.h"
#include "chrome/browser/task_manager/task_manager_interface.h"
#include "content/browser/renderer_host/render_frame_host_impl.h"
#include "content/public/browser/web_contents.h"
#include "content/public/browser/web_contents_observer.h"
#include "content/public/browser/web_contents_user_data.h"
#include "ui/accessibility/ax_action_data.h"
#include "ui/accessibility/ax_enums.mojom.h"
#include "ui/accessibility/ax_tree_id.h"
#include "ui/accessibility/ax_tree.h"
#include "ui/accessibility/ax_updates_and_events.h"

namespace {
class MajorisAXState : public content::WebContentsObserver,
                       public content::WebContentsUserData<MajorisAXState> {
 public:
  struct Tree { std::string document; ui::AXTree nodes; };
  std::map<ui::AXTreeID, std::unique_ptr<Tree>> trees;
  void RenderFrameDeleted(content::RenderFrameHost* frame) override {
    trees.erase(frame->GetAXTreeID());
  }
 private:
  friend class content::WebContentsUserData<MajorisAXState>;
  explicit MajorisAXState(content::WebContents* contents)
      : content::WebContentsObserver(contents),
        content::WebContentsUserData<MajorisAXState>(*contents) {}
  WEB_CONTENTS_USER_DATA_KEY_DECL();
};
WEB_CONTENTS_USER_DATA_KEY_IMPL(MajorisAXState);

MajorisAXState::Tree* CurrentTree(content::RenderFrameHostImpl* frame) {
  auto* contents = content::WebContents::FromRenderFrameHost(frame);
  auto* state = MajorisAXState::FromWebContents(contents);
  if (!state) return nullptr;
  auto found = state->trees.find(frame->GetAXTreeID());
  if (found == state->trees.end() ||
      found->second->document != frame->GetDocumentToken().ToString()) return nullptr;
  return found->second.get();
}
content::RenderFrameHostImpl* OwnedFrame(int browser_id, const char* tree) {
  if (!CefCurrentlyOn(TID_UI) || !tree || std::strlen(tree) > 64) return nullptr;
  // AXTreeID::FromString CHECKs on malformed input. Parse without terminating
  // the browser when an assistive client submits a malformed identifier.
  auto token = base::ValueToUnguessableToken(base::Value(tree));
  if (!token) return nullptr;
  auto browser = CefBrowserHostBase::GetBrowserForBrowserId(browser_id);
  if (!browser || !browser->GetWebContents()) return nullptr;
  auto* frame = content::RenderFrameHostImpl::FromAXTreeID(
      ui::AXTreeID::FromToken(*token));
  if (!frame || !frame->IsActive() || !frame->IsRenderFrameLive() ||
      content::WebContents::FromRenderFrameHost(frame) != browser->GetWebContents())
    return nullptr;
  return frame;
}
}  // namespace

void MajorisRecordAXUpdate(content::WebContents* contents,
                          const ui::AXUpdatesAndEvents& update) {
  if (!CefCurrentlyOn(TID_UI) || !contents) return;
  auto* frame = content::RenderFrameHostImpl::FromAXTreeID(update.ax_tree_id);
  if (!frame || !frame->IsActive() || !frame->IsRenderFrameLive() ||
      content::WebContents::FromRenderFrameHost(frame) != contents) return;
  MajorisAXState::CreateForWebContents(contents);
  auto* state = MajorisAXState::FromWebContents(contents);
  if (!state->trees.contains(update.ax_tree_id) && state->trees.size() >= 128) return;
  auto& tree = state->trees[update.ax_tree_id];
  auto token = frame->GetDocumentToken().ToString();
  if (!tree || tree->document != token) {
    tree = std::make_unique<MajorisAXState::Tree>();
    tree->document = token;
  }
  for (const auto& change : update.updates) {
    size_t total_nodes = 0;
    for (const auto& item : state->trees) total_nodes += item.second->nodes.size();
    if (change.nodes.size() > 20000 ||
        total_nodes + change.nodes.size() > 100000 ||
        tree->nodes.size() + change.nodes.size() > 40000 ||
        !tree->nodes.Unserialize(change)) {
      state->trees.erase(update.ax_tree_id);
      return;
    }
  }
}

extern "C" CEF_EXPORT uint64_t cef_majoris_runtime_capabilities(uint32_t abi) {
  if (abi != 1) return 0;
  uint64_t features = 2 | 4 | 8;  // AX actions, extended task metrics, history.
#if BUILDFLAG(IS_LINUX)
  if (base::CommandLine::ForCurrentProcess()->GetSwitchValueASCII(
          "ozone-platform") != "headless") features |= 1;
#endif
  return features;
}

// All node APIs run on the CEF UI thread. No Chromium pointers cross the ABI.
extern "C" CEF_EXPORT int cef_majoris_ax_document(
    int browser_id, const char* tree, char* output, size_t capacity) {
  auto* frame = OwnedFrame(browser_id, tree);
  if (!frame || !output || !CurrentTree(frame)) return 0;
  auto document = frame->GetDocumentToken().ToString();
  if (capacity <= document.size()) return 0;
  std::memcpy(output, document.c_str(), document.size() + 1);
  return 1;
}

extern "C" CEF_EXPORT int cef_majoris_ax_action(
    int browser_id, const char* tree, const char* document, int node_id,
    int operation, const char* value, int anchor, int focus) {
  auto* frame = OwnedFrame(browser_id, tree);
  if (!frame || !document || std::strlen(document) > 64 ||
      frame->GetDocumentToken().ToString() != document || node_id <= 0) return 0;
  auto* tree_state = CurrentTree(frame);
  auto* node = tree_state ? tree_state->nodes.GetFromId(node_id) : nullptr;
  if (!node) return 0;
  for (auto* ancestor = node; ancestor; ancestor = ancestor->parent())
    if (operation != 1 && ancestor->data().HasState(ax::mojom::State::kProtected)) return 0;
  ui::AXActionData action;
  action.target_tree_id = frame->GetAXTreeID();
  action.target_node_id = node_id;
  switch (operation) {
    case 0: action.action = ax::mojom::Action::kDoDefault; break;
    case 1: action.action = ax::mojom::Action::kFocus; break;
    case 2:
      if (!value || std::strlen(value) > 65536 || !base::IsStringUTF8(value) ||
          !node->data().HasState(ax::mojom::State::kEditable) ||
          node->data().GetRestriction() != ax::mojom::Restriction::kNone) return 0;
      action.action = ax::mojom::Action::kSetValue;
      action.value = value;
      break;
    case 3:
      if (anchor < 0 || focus < 0 || anchor > 1048576 || focus > 1048576 ||
          !node->data().HasState(ax::mojom::State::kEditable)) return 0;
      action.action = ax::mojom::Action::kSetSelection;
      action.anchor_node_id = action.focus_node_id = node_id;
      action.anchor_offset = anchor;
      action.focus_offset = focus;
      break;
    default: return 0;
  }
  frame->AccessibilityPerformAction(action);
  return 1;  // Dispatched, not a promise that the page accepted the action.
}

extern "C" CEF_EXPORT int cef_majoris_task_metrics(
    int64_t task_id, int64_t* pid, int64_t* network_bytes_per_second,
    int64_t* root_task_id) {
  if (!CefCurrentlyOn(TID_UI) || !pid || !network_bytes_per_second ||
      !root_task_id) return 0;
  // CEF owns the observer and refresh lifecycle. Never create a second global
  // sampler or infer parentage from OS process names.
  auto cef_manager = CefTaskManager::GetTaskManager();
  CefTaskInfo info;
  if (!cef_manager || !cef_manager->GetTaskInfo(task_id, info)) return 0;
  auto* manager = task_manager::TaskManagerInterface::GetTaskManager();
  if (!manager) return 0;
  const auto& tasks = manager->GetTaskIdsList();
  if (std::ranges::find(tasks, task_id) == tasks.end()) return 0;
  *pid = manager->GetProcessId(task_id);
  if (*pid <= 0) return 0;
  *root_task_id = manager->GetRootTaskId(task_id);
  *network_bytes_per_second = manager->GetNetworkUsage(task_id).InBytes();
  return 1;
}
