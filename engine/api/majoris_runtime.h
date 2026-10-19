// Majoris runtime extension ABI. Independent of the generated public CEF ABI.
#ifndef MAJORIS_RUNTIME_H_
#define MAJORIS_RUNTIME_H_
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
// Returns zero for an unsupported ABI. Bits: 0 native Linux video PiP,
// 1 validated AX transport, 2 task metrics, 3 navigation-entry persistence.
// This reports implemented engine functionality, not playback qualification.
uint64_t cef_majoris_runtime_capabilities(uint32_t abi_version);
// UI-thread-only; validates browser, tree ownership, active frame and document.
int cef_majoris_ax_document(int browser_id, const char* tree, char* output, size_t capacity);
// 0 default, 1 focus, 2 set value, 3 same-node selection (UTF-16 offsets).
// Success means dispatched. Protected fields permit focus only; writes fail.
int cef_majoris_ax_action(int browser_id, const char* tree, const char* document,
                         int node_id, int operation, const char* value,
                         int anchor, int focus);
// UI thread, live Chromium task IDs only; network is per task, bytes/second.
int cef_majoris_task_metrics(int64_t task_id, int64_t* pid,
                            int64_t* network_bytes_per_second,
                            int64_t* root_task_id);
// UI thread; persistent contexts only. Free snapshots with the paired function.
char* cef_majoris_history_snapshot(int browser_id);
void cef_majoris_history_free(void* data);
// Exact runtime/profile match, unused controller, no POST/files/unsafe URLs.
// Restores the controller at its selected index, without replaying old URLs.
int cef_majoris_history_restore(int browser_id,const char* data,size_t size);
#ifdef __cplusplus
}
#endif
#endif
