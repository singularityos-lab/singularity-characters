using Gtk;

namespace Singularity.Apps.Characters {

    public class CharactersApp : Singularity.Application {
        public GLib.Settings settings { get; private set; }
        private bool recent_pending;

        public CharactersApp () {
            Object (application_id: "dev.sinty.characters", flags: ApplicationFlags.DEFAULT_FLAGS);
            add_main_option ("recent", 0, OptionFlags.NONE, OptionArg.NONE, _("Show the recently used characters"), null);
        }

        protected override int handle_local_options (VariantDict options) {
            if (!options.contains ("recent")) return -1;
            try {
                register (null);
            } catch (Error e) {
                warning ("characters: %s", e.message);
                return 1;
            }
            if (get_is_remote ()) {
                activate_action ("show-recent", null);
                return 0;
            }
            recent_pending = true;
            return -1;
        }

        protected override void startup () {
            base.startup ();
            settings = new GLib.Settings ("dev.sinty.characters");
            IconTheme.get_for_display (Gdk.Display.get_default ()).add_resource_path ("/dev/sinty/characters/icons");
            var provider = new CssProvider ();
            provider.load_from_string (CSS);
            StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider, STYLE_PROVIDER_PRIORITY_USER + 1);

            var menu = new GLib.Menu ();
            var file_menu = new GLib.Menu ();
            file_menu.append (_("Close Window"), "win.close");
            file_menu.append (_("Quit"), "app.quit");
            menu.append_submenu (_("File"), file_menu);
            var edit_menu = new GLib.Menu ();
            var edit_copy = new GLib.Menu ();
            edit_copy.append (_("Copy Character"), "win.copy");
            edit_copy.append (_("Copy Code"), "win.copy-code");
            edit_menu.append_section (null, edit_copy);
            var edit_find = new GLib.Menu ();
            edit_find.append (_("Find"), "win.find");
            edit_menu.append_section (null, edit_find);
            var edit_settings = new GLib.Menu ();
            edit_settings.append (_("Settings"), "app.settings");
            edit_menu.append_section (null, edit_settings);
            menu.append_submenu (_("Edit"), edit_menu);
            var view_menu = new GLib.Menu ();
            view_menu.append (_("Toggle Sidebar"), "win.toggle-sidebar");
            menu.append_submenu (_("View"), view_menu);
            var go_menu = new GLib.Menu ();
            var go_recent = new GLib.Menu ();
            go_recent.append (_("Recently Used"), "win.category::recent");
            go_menu.append_section (null, go_recent);
            var go_emoji = new GLib.Menu ();
            go_emoji.append (_("Smileys & Emotion"), "win.category::smileys");
            go_emoji.append (_("People & Body"), "win.category::people");
            go_emoji.append (_("Animals & Nature"), "win.category::nature");
            go_emoji.append (_("Food & Drink"), "win.category::food");
            go_emoji.append (_("Travel & Places"), "win.category::travel");
            go_emoji.append (_("Activities"), "win.category::activities");
            go_emoji.append (_("Objects"), "win.category::objects");
            go_emoji.append (_("Symbols"), "win.category::symbols");
            go_emoji.append (_("Flags"), "win.category::flags");
            go_menu.append_section (_("Emoji"), go_emoji);
            var go_symbols = new GLib.Menu ();
            go_symbols.append (_("Punctuation"), "win.category::punctuation");
            go_symbols.append (_("Arrows"), "win.category::arrows");
            go_symbols.append (_("Math"), "win.category::math");
            go_symbols.append (_("Currency"), "win.category::currency");
            go_symbols.append (_("Letterlike"), "win.category::letterlike");
            go_symbols.append (_("Shapes & Technical"), "win.category::technical");
            go_menu.append_section (_("Symbols"), go_symbols);
            var go_letters = new GLib.Menu ();
            go_letters.append (_("Latin"), "win.category::latin");
            go_letters.append (_("Greek"), "win.category::greek");
            go_letters.append (_("Cyrillic"), "win.category::cyrillic");
            go_menu.append_section (_("Letters"), go_letters);
            menu.append_submenu (_("Go"), go_menu);
            set_menubar (menu);
            var quit_action = new SimpleAction ("quit", null);
            quit_action.activate.connect (() => quit ());
            add_action (quit_action);
            var settings_action = new SimpleAction ("settings", null);
            settings_action.activate.connect (() => {
                try {
                    Singularity.Shell.ShellService shell = Bus.get_proxy_sync (BusType.SESSION, "dev.sinty.desktop", "/dev/sinty/Shell");
                    shell.open_app_settings ("dev.sinty.characters");
                } catch (Error e) {
                    warning ("Failed to open settings: %s", e.message);
                }
            });
            add_action (settings_action);
            var recent_action = new SimpleAction ("show-recent", null);
            recent_action.activate.connect (() => {
                var window = ensure_window ();
                ((GLib.ActionGroup) window).activate_action ("category", new Variant.string ("recent"));
            });
            add_action (recent_action);
            set_accels_for_action ("app.quit", { "<Control>q" });
            set_accels_for_action ("app.settings", { "<Control>comma" });
            set_accels_for_action ("win.close", { "<Control>w" });
            set_accels_for_action ("win.toggle-sidebar", { "F9" });
        }

        private CharactersWindow ensure_window () {
            var window = get_active_window () as CharactersWindow;
            if (window == null) window = new CharactersWindow (this);
            window.present ();
            return window;
        }

        public override void activate () {
            var window = ensure_window ();
            if (recent_pending) {
                recent_pending = false;
                ((GLib.ActionGroup) window).activate_action ("category", new Variant.string ("recent"));
            }
        }

        public void show_character (CharItem item) {
            ensure_window ().reveal (item);
        }

        public void show_search (string text) {
            ensure_window ().search_for (text);
        }

        public string[] recent () {
            return settings.get_strv ("recent");
        }

        public void add_recent (string text) {
            string[] list = { text };
            foreach (string t in settings.get_strv ("recent")) {
                if (t == text) continue;
                if (list.length >= 60) break;
                list += t;
            }
            settings.set_strv ("recent", list);
        }

        private const string CSS = """
.characters-grid {
    background: transparent;
    padding: 0 18px 18px 18px;
}

.characters-grid > child {
    padding: 3px;
    margin: 2px;
    border-radius: 14px;
    transition: background-color 120ms ease;
}

.characters-grid > child:hover {
    background-color: alpha(@window_fg_color, 0.06);
}

.characters-grid > child:selected {
    background-color: alpha(@accent_bg_color, 0.22);
    color: inherit;
}

.characters-glyph {
    font-size: 30px;
}

.characters-panel {
    padding: 18px;
    border-radius: 20px;
    background-color: alpha(@window_fg_color, 0.05);
}

.characters-hero {
    font-size: 104px;
    border-radius: 16px;
    background-color: @view_bg_color;
}

.characters-code {
    font-family: monospace;
}

.characters-chip {
    padding: 2px 10px;
    border-radius: 999px;
    font-size: 12px;
    background-color: alpha(@accent_bg_color, 0.16);
    color: @accent_color;
}

.characters-variant {
    font-size: 24px;
    min-width: 40px;
    min-height: 40px;
    padding: 0;
    border-radius: 10px;
}
""";
    }

    public static int main (string[] args) {
        Intl.setlocale (LocaleCategory.ALL, "");
        string locale_dir = "/usr/share/locale";
        try {
            string exe = FileUtils.read_link ("/proc/self/exe");
            locale_dir = Path.build_filename (Path.get_dirname (Path.get_dirname (exe)), "share", "locale");
        } catch (Error e) {
        }
        Intl.bindtextdomain ("singularity-characters", locale_dir);
        Intl.bind_textdomain_codeset ("singularity-characters", "UTF-8");
        Intl.textdomain ("singularity-characters");
        Environment.set_application_name (_("Characters"));
        var app = new CharactersApp ();
        new CharactersSearch (app).export (app);
        return app.run (args);
    }
}
