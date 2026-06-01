---
name: xdg-open local files fails in this environment
description: xdg-open on file:// paths silently fails in Positron/VSCode terminal — use python http.server instead
metadata:
  type: feedback
---

`xdg-open /path/to/file.html` exits silently without launching a browser in this environment (Positron / VSCode terminal).

**Why:** Confirmed 2026-03-30. Affects skill eval review HTML files and any local HTML preview workflow.

**How to apply:** When needing to show an HTML file, start `python3 -m http.server` on localhost and give the user an `http://localhost:PORT/file.html` URL. Kill the server when done.
