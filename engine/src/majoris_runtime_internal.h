// Copyright 2026 Majoris Browser contributors. BSD-style license.
#ifndef CEF_LIBCEF_BROWSER_MAJORIS_RUNTIME_INTERNAL_H_
#define CEF_LIBCEF_BROWSER_MAJORIS_RUNTIME_INTERNAL_H_
namespace content { class WebContents; }
namespace ui { struct AXUpdatesAndEvents; }
// Called on the UI thread before forwarding authoritative OSR AX updates.
void MajorisRecordAXUpdate(content::WebContents*, const ui::AXUpdatesAndEvents&);
#endif
