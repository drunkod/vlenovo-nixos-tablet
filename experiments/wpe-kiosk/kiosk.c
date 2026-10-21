// Generation 59 — WPEPlatform 2.54 DRM/KMS Living Nebula kiosk.
// No GTK/Wayland/Cog; WPE_PLATFORM=drm selects internal atomic KMS.
// Startup URI defaults to the tablet's local authenticated scene viewer.
#include <wpe/webkit.h>
#include <wpe/wpe-platform.h>
#include <gio/gio.h>
#include <glib.h>
#include <glib-unix.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
static gboolean stop_signal(gpointer data) {
  g_main_loop_quit((GMainLoop *)data);
  return G_SOURCE_REMOVE;
}
static void on_load_changed(WebKitWebView *view, WebKitLoadEvent event, gpointer ignored) {
  if (event == WEBKIT_LOAD_FINISHED)
    fprintf(stderr, "WPE Gen59: page loaded: %s\n", webkit_web_view_get_uri(view));
}
static gboolean on_load_failed(WebKitWebView *view, WebKitLoadEvent event,
                                const char *uri, GError *error, gpointer ignored) {
  fprintf(stderr, "WPE Gen59: page load FAILED: %s: %s\n",
          uri ? uri : "(null)", error ? error->message : "(unspecified)");
  return FALSE;
}
int main(int argc, char **argv) {
  const char *uri = argc > 1 ? argv[1] : "http://127.0.0.1:17858/viewer";
  g_autoptr(GMainLoop) loop = g_main_loop_new(NULL, FALSE);
  g_autoptr(WebKitWebView) view = WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW, NULL));
  if (!view) {
    fprintf(stderr,"WPE: failed to construct WebKitWebView\n");
    return EXIT_FAILURE;
  }
  // The runtime always starts from the local trusted scene.
  g_signal_connect(view, "load-changed", G_CALLBACK(on_load_changed), NULL);
  g_signal_connect(view, "load-failed", G_CALLBACK(on_load_failed), NULL);
  g_unix_signal_add(SIGINT, stop_signal, loop);
  g_unix_signal_add(SIGTERM, stop_signal, loop);
  fprintf(stderr, "WPE Gen59: initializing %s (WPE_PLATFORM=%s)\n",
    uri, getenv("WPE_PLATFORM") ? getenv("WPE_PLATFORM") : "auto");
  webkit_web_view_load_uri(view, uri);
  g_main_loop_run(loop);
  fprintf(stderr, "WPE Gen59: leaving main loop\n");
  return EXIT_SUCCESS;
}
