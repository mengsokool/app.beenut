#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "beenut_shm_texture.h"
#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlView* view;
  FlMethodChannel* preview_channel;
  BeenutShmTexture* preview_texture;
  guint preview_timer_id;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gboolean preview_timer_cb(gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->preview_texture == nullptr || self->view == nullptr) {
    return G_SOURCE_CONTINUE;
  }
  if (!beenut_shm_texture_has_new_frame(self->preview_texture)) {
    return G_SOURCE_CONTINUE;
  }
  FlEngine* engine = fl_view_get_engine(self->view);
  FlTextureRegistrar* texture_registrar =
      fl_engine_get_texture_registrar(engine);
  fl_texture_registrar_mark_texture_frame_available(
      texture_registrar, FL_TEXTURE(self->preview_texture));
  return G_SOURCE_CONTINUE;
}

static FlMethodResponse* handle_preview_create(MyApplication* self,
                                               FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "bad_args", "Expected map arguments", nullptr));
  }
  g_autoptr(FlValue) path_key = fl_value_new_string("path");
  FlValue* path_value = fl_value_lookup(args, path_key);
  if (path_value == nullptr ||
      fl_value_get_type(path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "bad_args", "Missing shared memory path", nullptr));
  }

  FlEngine* engine = fl_view_get_engine(self->view);
  FlTextureRegistrar* texture_registrar =
      fl_engine_get_texture_registrar(engine);
  if (self->preview_texture != nullptr) {
    fl_texture_registrar_unregister_texture(
        texture_registrar, FL_TEXTURE(self->preview_texture));
    g_clear_object(&self->preview_texture);
  }

  self->preview_texture =
      beenut_shm_texture_new(fl_value_get_string(path_value));
  if (!fl_texture_registrar_register_texture(
          texture_registrar, FL_TEXTURE(self->preview_texture))) {
    g_clear_object(&self->preview_texture);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "texture_error", "Failed to register preview texture", nullptr));
  }

  if (self->preview_timer_id == 0) {
    self->preview_timer_id = g_timeout_add(16, preview_timer_cb, self);
  }

  g_autoptr(FlValue) id =
      fl_value_new_int(fl_texture_get_id(FL_TEXTURE(self->preview_texture)));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(id));
}

static FlMethodResponse* handle_preview_dispose(MyApplication* self,
                                                FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "bad_args", "Expected map arguments", nullptr));
  }

  if (self->preview_texture != nullptr) {
    FlEngine* engine = fl_view_get_engine(self->view);
    FlTextureRegistrar* texture_registrar =
        fl_engine_get_texture_registrar(engine);
    fl_texture_registrar_unregister_texture(
        texture_registrar, FL_TEXTURE(self->preview_texture));
    g_clear_object(&self->preview_texture);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static void preview_channel_method_cb(FlMethodChannel* channel,
                                      FlMethodCall* method_call,
                                      gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const char* name = fl_method_call_get_name(method_call);
  if (g_str_equal(name, "create")) {
    g_autoptr(FlMethodResponse) response =
        handle_preview_create(self, method_call);
    fl_method_call_respond(method_call, response, nullptr);
  } else if (g_str_equal(name, "dispose")) {
    g_autoptr(FlMethodResponse) response =
        handle_preview_dispose(self, method_call);
    fl_method_call_respond(method_call, response, nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  const gchar* no_titlebar_env = g_getenv("BEENUT_NO_TITLEBAR");
  gboolean no_titlebar = (no_titlebar_env != nullptr && g_strcmp0(no_titlebar_env, "1") == 0);

  gboolean use_header_bar = TRUE;
  if (no_titlebar) {
    gtk_window_set_decorated(window, FALSE);
    use_header_bar = FALSE;
  } else {
    // Use a header bar when running in GNOME as this is the common style used
    // by applications and is the setup most users will be using (e.g. Ubuntu
    // desktop).
    // If running on X and not using GNOME then just use a traditional title bar
    // in case the window manager does more exotic layout, e.g. tiling.
    // If running on Wayland assume the header bar will work (may need changing
    // if future cases occur).
#ifdef GDK_WINDOWING_X11
    GdkScreen* screen = gtk_window_get_screen(window);
    if (GDK_IS_X11_SCREEN(screen)) {
      const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
      if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
        use_header_bar = FALSE;
      }
    }
#endif
  }

  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "BeeNut");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "BeeNut");
  }

  gtk_window_set_default_size(window, 960, 540);
  gtk_widget_set_size_request(GTK_WIDGET(window), 420, 300);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  self->view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(self->view, &background_color);
  gtk_widget_show(GTK_WIDGET(self->view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(self->view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(self->view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(self->view));

  FlEngine* engine = fl_view_get_engine(self->view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->preview_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(engine), "beenut/preview_texture",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->preview_channel, preview_channel_method_cb, self, nullptr);

  fl_register_plugins(FL_PLUGIN_REGISTRY(self->view));

  gtk_widget_grab_focus(GTK_WIDGET(self->view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  if (self->preview_timer_id != 0) {
    g_source_remove(self->preview_timer_id);
    self->preview_timer_id = 0;
  }
  g_clear_object(&self->preview_texture);
  g_clear_object(&self->preview_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
