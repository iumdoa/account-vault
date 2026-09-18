#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* window_channel;
  gboolean application_held;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Niri IPC window focus helper
static void focus_niri_window() {
  const gchar* wayland_display = g_getenv("WAYLAND_DISPLAY");
  if (wayland_display == nullptr) {
    return;
  }

  gchar* standard_output = nullptr;
  gchar* standard_error = nullptr;
  gint exit_status = 0;
  gchar* argv[] = {const_cast<gchar*>("niri"),
                   const_cast<gchar*>("msg"),
                   const_cast<gchar*>("--json"),
                   const_cast<gchar*>("windows"),
                   nullptr};

  gboolean success = g_spawn_sync(nullptr, argv, nullptr,
                                  G_SPAWN_SEARCH_PATH, nullptr, nullptr,
                                  &standard_output, &standard_error,
                                  &exit_status, nullptr);
  if (!success || exit_status != 0 || standard_output == nullptr) {
    g_free(standard_output);
    g_free(standard_error);
    return;
  }

  gchar* target = g_strstr_len(standard_output, -1, "\"app_id\":\"dev.local.account_vault\"");
  if (target != nullptr) {
    gchar* id_pos = nullptr;
    for (gchar* p = target; p >= standard_output; --p) {
      if (g_str_has_prefix(p, "\"id\":")) {
        id_pos = p + 5;
        break;
      }
    }
    if (id_pos != nullptr) {
      gint64 window_id = g_ascii_strtoll(id_pos, nullptr, 10);
      if (window_id > 0) {
        gchar id_str[32];
        g_snprintf(id_str, sizeof(id_str), "%" G_GINT64_FORMAT, window_id);
        gchar* focus_argv[] = {const_cast<gchar*>("niri"),
                               const_cast<gchar*>("msg"),
                               const_cast<gchar*>("action"),
                               const_cast<gchar*>("focus-window"),
                               const_cast<gchar*>("--id"),
                               id_str,
                               nullptr};
        g_spawn_sync(nullptr, focus_argv, nullptr, G_SPAWN_SEARCH_PATH,
                     nullptr, nullptr, nullptr, nullptr, nullptr, nullptr);
      }
    }
  }

  g_free(standard_output);
  g_free(standard_error);
}

static void notify_flutter_show(MyApplication* self) {
  if (self->window_channel != nullptr) {
    fl_method_channel_invoke_method(self->window_channel, "onShow", nullptr,
                                    nullptr, nullptr, nullptr);
  }
}

static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (g_strcmp0(method, "hideWindow") == 0) {
    if (self->window != nullptr) {
      gtk_widget_hide(GTK_WIDGET(self->window));
    }
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_strcmp0(method, "showWindow") == 0) {
    if (self->window != nullptr) {
      gtk_widget_show(GTK_WIDGET(self->window));
      gtk_window_present(self->window);
      focus_niri_window();
    }
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_strcmp0(method, "quitApp") == 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    fl_method_call_respond(method_call, response, nullptr);
    if (self->application_held) {
      g_application_release(G_APPLICATION(self));
      self->application_held = FALSE;
    }
    g_application_quit(G_APPLICATION(self));
  } else {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
  }
}

static gboolean on_window_delete_event(GtkWidget* widget, GdkEvent* event, gpointer user_data) {
  gtk_widget_hide(widget);
  return TRUE;
}

static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  focus_niri_window();
}

static void create_window(MyApplication* self) {
  if (self->window != nullptr) {
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(self)));
  self->window = window;

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Account Vault");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Account Vault");
  }

  gtk_window_set_default_size(window, 680, 460);

  g_signal_connect(window, "delete-event", G_CALLBACK(on_window_delete_event), self);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(messenger,
                                              "dev.local.account_vault/window",
                                              FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                            window_method_call_cb,
                                            self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));

  if (!self->application_held) {
    g_application_hold(G_APPLICATION(self));
    self->application_held = TRUE;
  }
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window == nullptr) {
    create_window(self);
  }
  gtk_widget_show(GTK_WIDGET(self->window));
  gtk_window_present(self->window);
  focus_niri_window();
  notify_flutter_show(self);
}

static int my_application_command_line(GApplication* application,
                                       GApplicationCommandLine* cmdline) {
  MyApplication* self = MY_APPLICATION(application);
  gint argc = 0;
  gchar** argv = g_application_command_line_get_arguments(cmdline, &argc);

  gboolean show_req = FALSE;
  gboolean hide_req = FALSE;
  gboolean quit_req = FALSE;

  for (gint i = 1; i < argc; ++i) {
    if (g_strcmp0(argv[i], "--show") == 0) {
      show_req = TRUE;
    } else if (g_strcmp0(argv[i], "--hide") == 0) {
      hide_req = TRUE;
    } else if (g_strcmp0(argv[i], "--quit") == 0) {
      quit_req = TRUE;
    }
  }

  if (!hide_req && !quit_req) {
    show_req = TRUE;
  }

  if (quit_req) {
    if (self->application_held) {
      g_application_release(application);
      self->application_held = FALSE;
    }
    g_application_quit(application);
    g_strfreev(argv);
    return 0;
  }

  if (self->window == nullptr) {
    self->dart_entrypoint_arguments = g_strdupv(argv + 1);
    create_window(self);
    gtk_widget_show(GTK_WIDGET(self->window));
    gtk_window_present(self->window);
  } else {
    if (hide_req) {
      gtk_widget_hide(GTK_WIDGET(self->window));
    } else if (show_req) {
      gtk_widget_show(GTK_WIDGET(self->window));
      gtk_window_present(self->window);
      focus_niri_window();
      notify_flutter_show(self);
    }
  }

  g_strfreev(argv);
  return 0;
}

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->window_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->window = nullptr;
  self->window_channel = nullptr;
  self->dart_entrypoint_arguments = nullptr;
  self->application_held = FALSE;
}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_HANDLES_COMMAND_LINE,
                                     nullptr));
}
