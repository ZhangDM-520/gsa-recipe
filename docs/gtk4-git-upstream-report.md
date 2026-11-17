---
permalink: gsa-recipe/docs/gtk4-git-upstream-report
title: gtk4-git-upstream-report
type: note
---

# gtk4-git upstream report (ARCHIVED, UNFILED)

Not filed upstream: the owner's decision 2026-11-16 (GitLab auth gate, no
credentials). The fix is carried in `packages/gtk4-git/atspi-action-getproperty-error.patch`
(pkgrel 3) instead. Full repro evidence and ROOT-CAUSE live in the lab dir
`~/Projects/.workspace/PERMANENT/gdbus-assert/`. The text below is the report
as drafted.

---

# Draft: GTK 4.26 AT-SPI — `Action.NActions` getter returns (NULL, NULL), aborts the app

Project: GNOME / gtk (GitLab).  Status: DRAFT — file only after owner review.

## Summary

`org.a11y.atspi.Action.NActions` is advertised on every `GtkWidget` accessible,
but `widget_handle_get_property()` returns `NULL` without setting a `GError`
when the widget has no action node:

```c
/* gtk/a11y/gtkatspiaction.c */
  if (node == NULL)
    return res;      /* res is NULL and *error is untouched */
```

GLib's `GDBusInterfaceVTable` contract requires `*error` to be set whenever the
get_property callback returns `NULL`; `invoke_get_property_in_idle_cb()` in
`gio/gdbusconnection.c` asserts this and the server process is aborted:

```
GLib-GIO:ERROR:../gio/gdbusconnection.c:4765:invoke_get_property_in_idle_cb:
assertion failed: (error != NULL)
```

Any AT-SPI client that reads `NActions` (screen readers, accessibility
inspectors, automated AT walkers) kills the app. This is a crash of the
"provider" side caused by incoming D-Bus traffic; no user action in the app is
involved.

## Affected versions

* gtk 4.25/4.26 development (verified at `e47186dc57`, 2026-11-12);
  `gtk4-git 4.26.r114.ge47186d-1` on Arch.
* It became trivially reachable with `5a6802cae5` ("gtk: Use GtkActionTree
  throughout GTK", 2026-09-04): `_gtk_widget_get_action_node()` returns `NULL`
  for the many widgets that have no actions, whereas the old
  `_gtk_widget_get_action_muxer()` existed for most widgets.
* Released 4.24.1 does not abort for the same call (verified in a container:
  it answers `NActions = 0`), so this is a development-branch regression in
  practice. The missing `g_set_error()` itself is old (the early return dates
  back to the initial 2020 AT-SPI action implementation).

## Steps to reproduce (standalone, no application code)

Build/run a 25-line GTK4 window:

```c
/* mini-gtk.c */
#include <gtk/gtk.h>
static void activate(GtkApplication *app, gpointer data)
{
  GtkWidget *win = gtk_application_window_new(app);
  gtk_window_set_default_size(GTK_WINDOW(win), 640, 480);
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
  gtk_box_append(GTK_BOX(box), gtk_label_new("hello"));
  gtk_window_set_child(GTK_WINDOW(win), box);
  gtk_window_present(GTK_WINDOW(win));
}
int main(int argc, char **argv)
{
  GtkApplication *app = gtk_application_new("org.gtk.repro", G_APPLICATION_DEFAULT_FLAGS);
  g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
  return g_application_run(G_APPLICATION(app), argc, argv);
}
```

Run it against a private accessibility bus:

```sh
# 1. accessibility bus (dbus-daemon is enough; no session bus needed)
ADDR=$(dbus-daemon --session --print-address=1 --fork)
export AT_SPI_BUS_ADDRESS=$ADDR
# 2. registry daemon (libatspi honours AT_SPI_BUS_ADDRESS)
/usr/lib/at-spi2-registryd --dbus-name org.a11y.atspi.Registry &
# 3. the app
DISPLAY=:97 ./mini-gtk &          # any X11 or Wayland display

# 4. three D-Bus calls (the last one is fatal)
DEST=:1.1                          # the app's unique name
ROOT=/org/a11y/atspi/accessible/root
WIN=$(gdbus call --address "$ADDR" --dest $DEST --object-path $ROOT \
        --method org.a11y.atspi.Accessible.GetChildAtIndex 0 | grep -o "/org/[^']*")
NODE=$(gdbus call --address "$ADDR" --dest $DEST --object-path "$WIN" \
        --method org.a11y.atspi.Accessible.GetChildAtIndex 0 | grep -o "/org/[^']*")
gdbus call --address "$ADDR" --dest $DEST --object-path "$NODE" \
        --method org.freedesktop.DBus.Properties.Get \
        org.a11y.atspi.Action NActions
```

### Expected

A D-Bus error (the widget has no actions), or `NActions = 0`.

### Actual

```
Error: GDBus.Error:org.freedesktop.DBus.Error.NoReply:
  Message recipient disconnected from message bus without replying
```

and the app's stderr:

```
GLib-GIO:ERROR:../gio/gdbusconnection.c:4765:invoke_get_property_in_idle_cb:
assertion failed: (error != NULL)
Bail out! GLib-GIO:ERROR:... (SIGABRT)
```

Backtrace (glib 2.91.0 / gtk main, `ghostty` as provider):

```
#3 abort
#4 g_assertion_message_expr
#5 invoke_get_property_in_idle_cb          gio/gdbusconnection.c:4765
#6 g_main_context_dispatch
#7 g_main_context_iteration
```

## Root cause

`gtk_atspi_get_action_vtable()` returns `widget_action_vtable` for every
`GTK_IS_WIDGET (accessible)` and the interface is registered on every
context, so `org.a11y.atspi.Action` is always in `GetInterfaces()`. The
vtable's `get_property` handler:

```c
  GtkActionNode *node = _gtk_widget_get_action_node (widget, FALSE);
  GVariant *res = NULL;

  if (node == NULL)
    return res;                 /* <- *error not set */

  char **actions = gtk_action_node_list_actions (node, TRUE);
  int n_actions = actions != NULL ? g_strv_length (actions) : 0;

  if (g_strcmp0 (property_name, "NActions") == 0)
    res = g_variant_new_int32 (get_valid_actions (node, actions, n_actions));
  else
    g_set_error (error, G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED,
                 "Unknown property '%s'", property_name);
  return res;
```

gio validates that the requested property exists in the registered XML, then
calls the callback in an idle handler and asserts the vtable contract. The
whole application aborts.

## Proposed patch

```diff
--- a/gtk/a11y/gtkatspiaction.c
+++ b/gtk/a11y/gtkatspiaction.c
@@ -1016,7 +1016,11 @@ widget_handle_get_property (GDBusConnection  *connection,
   GVariant *res = NULL;
 
   if (node == NULL)
-    return res;
+    {
+      g_set_error (error, G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED,
+                   "No actions for widget of type %s", G_OBJECT_TYPE_NAME (widget));
+      return NULL;
+    }
 
   char **actions = gtk_action_node_list_actions (node, TRUE);
```

`fix.diff` in this directory is the same patch; it applies to `e47186dc57`
with `git apply`.

(Alternative considered: answer `NActions = 0` for `node == NULL`; that also
satisfies the contract, but an explicit error keeps the distinction between
"no actions" and a getter that cannot answer, and matches the existing
`g_set_error()` for unknown properties. Either way the `g_assert` must never
be reachable.)

## Verification

Environment: container root (Arch, `systemd-nspawn`); glib built from
`107dde1` (2.91.0), gtk from `e47186dc57` (4.26-dev), at-spi2-core 2.62.1
registry, Xvfb + llvmpipe, provider binary = the distribution ghostty
1.4.0.r374.g46f1cea1a.

* Before: `NActions` on the first non-action widget aborts the app (`SIGABRT`,
  assertion line 4765).
* After: the same call returns
  `G_IO_ERROR_NOT_SUPPORTED: No actions for widget of type GtkBox` (or
  `AdwDialogHost` / `GhosttyRenderSurface`), the app survives a full walk of
  61 accessible nodes (43 Action nodes without actions).
* A/B: gtk 4.24.1 answers `NActions = 0` for the same object, i.e. the abort is
  a main-branch regression in practice.

## Notes

The same "return NULL without an error" shape exists in a few other AT-SPI
getters (`gtkatspitext.c`, `gtkatspiselection.c`, `gtkatspivalue.c`), but
those paths are currently unreachable through `Properties.Get` because the
property is filtered against the registered interface XML. Fixing them is
optional hardening; the `Action` getter is the reachable one.

Logs, harness and the unit-style GTK app are attached in `repro/` in the
report bundle (not part of the patch).

## Appendix — provider-side context (ghostty, no action required)

The crash was first seen with ghostty 1.4.0.r374.g46f1cea1a (GTK4 + libadwaita)
as the D-Bus provider: an AT-SPI tree walk read `NActions` on an
`AdwDialogHost` and aborted the terminal. Re-running the same walk in a lab
against the distribution ghostty binary reproduces the abort at the first
widget without actions (43 of 61 nodes); after the GTK patch the same walk
completes. No ghostty code change is needed — any GTK4 application that
exports an accessible tree is affected the same way.
