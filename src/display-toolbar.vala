// This file is part of GNOME Boxes. License: LGPLv2+
using Gtk;

[GtkTemplate (ui = "/org/gnome/Boxes/ui/display-toolbar.ui")]
private class Boxes.DisplayToolbar: Gtk.HeaderBar {
    public bool overlay { get; construct; }
    public bool handle_drag { get; construct; } // Handle drag events to (un)fulscreen the main window

    [GtkChild]
    private Gtk.Image back_image;
    [GtkChild]
    private Gtk.Image fullscreen_image;
    [GtkChild]
    private Gtk.Button back;
    [GtkChild]
    private Gtk.Button fullscreen;
    [GtkChild]
    private Gtk.Button props;

    public DisplayToolbar (bool overlay, bool handle_drag) {
        Object (overlay: overlay,
                handle_drag: handle_drag);
    }

    construct {
        add_events (Gdk.EventMask.POINTER_MOTION_MASK |
                    Gdk.EventMask.BUTTON_PRESS_MASK |
                    Gdk.EventMask.BUTTON_RELEASE_MASK);

        if (overlay) {
            get_style_context ().add_class ("toolbar");
            get_style_context ().add_class ("osd");
        } else {
            get_style_context ().add_class (Gtk.STYLE_CLASS_MENUBAR);
            show_close_button = true;
        }

        back_image.icon_name = (get_direction () == Gtk.TextDirection.RTL)? "go-previous-rtl-symbolic" :
                                                                            "go-previous-symbolic";
        if (!overlay) {
            back.get_style_context ().add_class ("raised");
            fullscreen.get_style_context ().add_class ("raised");
            props.get_style_context ().add_class ("raised");
        }

        App.app.notify["fullscreen"].connect_after ( () => {
            if (App.app.fullscreen)
                fullscreen_image.icon_name = "view-restore-symbolic";
            else
                fullscreen_image.icon_name = "view-fullscreen-symbolic";
        });
    }

    private bool button_down;
    private int button_down_x;
    private int button_down_y;
    private uint button_down_button;

    public override bool button_press_event (Gdk.EventButton event) {
        var res = base.button_press_event (event);
        if (!handle_drag)
            return res;

        // With the current GdkEvent bindings this is the only way to
        // upcast a GdkEventButton to a GdkEvent (which we need for
        // the triggerts_context_menu() method call.
        // TODO: Fix this when vala bindings are corrected
        Gdk.Event *base_event = (Gdk.Event *)(&event);

        if (!res && !base_event->triggers_context_menu ()) {
            button_down = true;
            button_down_button = event.button;
            button_down_x = (int) event.x;
            button_down_y = (int) event.y;
        }
        return res;
    }

    public override bool button_release_event (Gdk.EventButton event) {
        button_down = false;
        return base.button_press_event (event);
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        if (!handle_drag)
            return base.motion_notify_event (event);

        if (button_down) {
            double dx = event.x - button_down_x;
            double dy = event.y - button_down_y;

            // Break out when the dragged distance is 40 pixels
            if (dx * dx + dy * dy > 40 * 40) {
                button_down = false;
                App.app.fullscreen = false;

                var window = get_toplevel () as Gtk.Window;
                int old_width;
                window.get_size (out old_width, null);

                ulong id = 0;
                id = App.app.notify["fullscreen"].connect ( () => {
                    int root_x, root_y, width;
                    window.get_position (out root_x, out root_y);
                    window.get_window ().get_geometry (null, null, out width, null);
                    window.begin_move_drag ((int) button_down_button,
                                            root_x + (int) ((button_down_x / (double) old_width) * width),
                                            root_y + button_down_y,
                                            event.time);
                    App.app.disconnect (id);
                } );
            }
        }
        if (base.motion_notify_event != null)
            return base.motion_notify_event (event);
        return false;
    }

    [GtkCallback]
    private void on_back_clicked () {
        App.app.set_state (UIState.COLLECTION);
    }

    [GtkCallback]
    private void on_fullscreen_clicked () {
        App.app.fullscreen = !App.app.fullscreen;
    }

    [GtkCallback]
    private void on_props_clicked () {
        App.app.set_state (UIState.PROPERTIES);
    }
}