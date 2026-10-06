using Gtk;
using GLib;
using Singularity;

namespace SingularityCharactersWidget {

    public class RecentProvider : Object, OverviewWidgetProvider {
        public string id           { get { return "characters.recent"; } }
        public string provider_id  { get { return "dev.sinty.characters"; } }
        public string display_name { get { return _("Recent Characters"); } }
        public string icon_name    { get { return "dev.sinty.characters"; } }
        public WidgetSize[] supported_sizes {
            get {
                if (_sizes == null) {
                    _sizes = new WidgetSize[3];
                    _sizes[0] = WidgetSize(2, 1);
                    _sizes[1] = WidgetSize(2, 2);
                    _sizes[2] = WidgetSize(4, 1);
                }
                return _sizes;
            }
        }
        private WidgetSize[] _sizes;
        public Gtk.Widget create_instance(string instance_id, WidgetSize size, Variant? config) {
            return new RecentInstance(size);
        }
    }

    public class RecentInstance : Gtk.Box {
        private GLib.Settings? settings = null;
        private Gtk.Grid grid;
        private Gtk.Label header;
        private Gtk.Label empty_lbl;
        private int columns;
        private int rows;
        private uint reset_id = 0;

        public RecentInstance(WidgetSize size) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);
            add_css_class("overview-widget-card");
            overflow = Overflow.HIDDEN;
            hexpand = true; vexpand = true;
            columns = size.w * 3;
            rows = size.h;

            header = new Gtk.Label(_("Recent Characters"));
            header.add_css_class("caption-heading");
            header.opacity = 0.7;
            header.halign = Align.START;
            header.margin_start = 14; header.margin_top = 10;
            append(header);

            grid = new Gtk.Grid();
            grid.column_homogeneous = true;
            grid.row_homogeneous = true;
            grid.column_spacing = 6;
            grid.row_spacing = 6;
            grid.margin_start = 10; grid.margin_end = 10;
            grid.margin_bottom = 10;
            grid.hexpand = true; grid.vexpand = true;
            append(grid);

            empty_lbl = new Gtk.Label(_("Characters you copy appear here"));
            empty_lbl.add_css_class("dim-label");
            empty_lbl.wrap = true;
            empty_lbl.justify = Justification.CENTER;
            empty_lbl.hexpand = true; empty_lbl.vexpand = true;
            append(empty_lbl);

            var source = SettingsSchemaSource.get_default();
            if (source != null && source.lookup("dev.sinty.characters", true) != null) {
                settings = new GLib.Settings("dev.sinty.characters");
                settings.changed["recent"].connect(refresh);
            }
            refresh();
            destroy.connect(() => {
                if (reset_id != 0) { GLib.Source.remove(reset_id); reset_id = 0; }
            });
        }

        private void refresh() {
            Widget? child;
            while ((child = grid.get_first_child()) != null) grid.remove(child);
            string[] recent = settings != null ? settings.get_strv("recent") : new string[0];
            int count = int.min(recent.length, columns * rows);
            for (int i = 0; i < count; i++) {
                grid.attach(make_button(recent[i]), i % columns, i / columns);
            }
            for (int i = count; i < columns; i++) {
                var spacer = new Gtk.Box(Orientation.HORIZONTAL, 0);
                grid.attach(spacer, i, 0);
            }
            grid.visible = count > 0;
            empty_lbl.visible = count == 0;
        }

        private Widget make_button(string text) {
            var button = new Gtk.Button();
            button.add_css_class("flat");
            button.add_css_class("overview-widget-tile");
            var label = new Gtk.Label(text);
            label.add_css_class("title-2");
            button.child = label;
            button.tooltip_text = _("Copy %s").printf(text);
            button.clicked.connect(() => copy(text));
            return button;
        }

        private void copy(string text) {
            get_clipboard().set_text(text);
            header.label = _("Copied %s").printf(text);
            if (reset_id != 0) GLib.Source.remove(reset_id);
            reset_id = GLib.Timeout.add(1500, () => {
                reset_id = 0;
                header.label = _("Recent Characters");
                return GLib.Source.REMOVE;
            });
            if (settings == null) return;
            string[] list = { text };
            foreach (string t in settings.get_strv("recent")) {
                if (t == text) continue;
                if (list.length >= 60) break;
                list += t;
            }
            settings.set_strv("recent", list);
        }
    }

    [CCode (cname = "singularity_characters_widget_new")]
    public static Object singularity_characters_widget_new() {
        string locale_dir = "/usr/share/locale";
        try {
            string exe = FileUtils.read_link("/proc/self/exe");
            locale_dir = Path.build_filename(Path.get_dirname(Path.get_dirname(exe)), "share", "locale");
        } catch (Error e) { }
        Intl.bindtextdomain("singularity-characters", locale_dir);
        Intl.bind_textdomain_codeset("singularity-characters", "UTF-8");
        return new RecentProvider();
    }
}
