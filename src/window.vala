using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Characters {

    public class CharactersWindow : Singularity.Widgets.Window {
        private struct Category {
            public string id;
            public string label;
            public string icon;
        }

        private CharactersApp app;
        private Database db;
        private AppSidebar sidebar;
        private Gee.HashMap<string, SidebarRow> rows = new Gee.HashMap<string, SidebarRow> ();
        private string current = "smileys";
        private GLib.ListStore store;
        private SingleSelection selection;
        private GridView grid;
        private Stack stack;
        private StatusPage empty;
        private Box header;
        private Label title;
        private Label subtitle;
        private Revealer panel_revealer;
        private Label hero;
        private Label char_name;
        private Label char_code;
        private Label char_group;
        private FlowBox variants;
        private Label variants_title;
        private Button case_button;
        private Label copied;
        private uint copied_source = 0;
        private CharItem? shown = null;
        private string query = "";
        private SearchBubble search;
        private CharItem? pending_reveal = null;

        public CharactersWindow (CharactersApp app) {
            Object (application: app);
            this.app = app;
            db = Database.get_default ();
            set_default_size (1060, 720);
            set_title (_("Characters"));

            sidebar = new AppSidebar (220);
            build_sidebar ();
            set_sidebar (sidebar);
            set_sidebar_visible (true);

            search = add_bubble_search (_("Search Characters"), (text) => {
                query = text;
                refresh ();
            });
            search.entry.input_hints = InputHints.NO_SPELLCHECK | InputHints.NO_EMOJI;
            copied = add_bubble_label ("", force_ssd);
            copied.visible = false;

            var content = new Box (Orientation.HORIZONTAL, 0);
            var main = new Box (Orientation.VERTICAL, 0);
            main.hexpand = true;
            header = new Box (Orientation.VERTICAL, 2);
            header.margin_start = 24;
            header.margin_end = 24;
            header.margin_bottom = 10;
            header.margin_top = 16;
            Singularity.Widgets.apply_view_edge (header);
            title = new Label ("");
            title.xalign = 0;
            title.add_css_class ("title-2");
            subtitle = new Label ("");
            subtitle.xalign = 0;
            subtitle.add_css_class ("dim-label");
            header.append (title);
            header.append (subtitle);
            main.append (header);

            store = new GLib.ListStore (typeof (CharItem));
            selection = new SingleSelection (store);
            selection.autoselect = false;
            selection.can_unselect = true;
            selection.selected = Gtk.INVALID_LIST_POSITION;
            selection.notify["selected"].connect (on_selected);
            var factory = new SignalListItemFactory ();
            factory.setup.connect ((obj) => {
                var li = (ListItem) obj;
                var glyph = new Label ("");
                glyph.add_css_class ("characters-glyph");
                glyph.set_size_request (64, 64);
                glyph.halign = Align.CENTER;
                glyph.valign = Align.CENTER;
                li.child = glyph;
            });
            factory.bind.connect ((obj) => {
                var li = (ListItem) obj;
                var item = (CharItem) li.item;
                var glyph = (Label) li.child;
                glyph.label = item.text;
                glyph.tooltip_text = item.display_name ();
            });
            grid = new GridView (selection, factory);
            grid.add_css_class ("characters-grid");
            grid.max_columns = 40;
            grid.min_columns = 3;
            grid.activate.connect ((pos) => {
                var item = (CharItem) store.get_item (pos);
                if (item != null) copy (item);
            });
            var scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.vexpand = true;
            scroll.child = grid;

            empty = new StatusPage ();
            empty.icon_name = "system-search";
            empty.title = _("No Characters Found");
            empty.description = _("Try another word, or type a code such as U+263A.");
            var clear = new Button.with_label (_("Clear Search"));
            clear.halign = Align.CENTER;
            clear.add_css_class ("pill");
            clear.add_css_class ("suggested-action");
            clear.clicked.connect (() => {
                search.entry.text = "";
                query = "";
                refresh ();
            });
            empty.child = clear;
            stack = new Stack ();
            stack.transition_type = StackTransitionType.CROSSFADE;
            stack.add_named (scroll, "grid");
            stack.add_named (empty, "empty");
            stack.add_named (build_recent_empty (), "recent-empty");
            main.append (stack);
            content.append (main);

            panel_revealer = new Revealer ();
            panel_revealer.transition_type = RevealerTransitionType.SLIDE_LEFT;
            panel_revealer.child = build_panel ();
            panel_revealer.reveal_child = false;
            content.append (panel_revealer);

            set_content (content);

            var keys = new EventControllerKey ();
            keys.key_pressed.connect ((keyval, code, state) => {
                if (keyval == Gdk.Key.Escape && selection.selected != Gtk.INVALID_LIST_POSITION) {
                    selection.selected = Gtk.INVALID_LIST_POSITION;
                    return true;
                }
                if ((state & Gdk.ModifierType.CONTROL_MASK) != 0 && (keyval == Gdk.Key.c || keyval == Gdk.Key.C) && shown != null && !(get_focus () is Editable)) {
                    copy (shown);
                    return true;
                }
                if ((state & Gdk.ModifierType.CONTROL_MASK) != 0 && (keyval == Gdk.Key.f || keyval == Gdk.Key.F)) {
                    search.grab_focus_entry ();
                    return true;
                }
                return false;
            });
            ((Widget) this).add_controller (keys);

            var entries = new ActionEntry[] {
                { "copy", () => { if (shown != null) copy (shown); } },
                { "copy-code", () => copy_shown_code () },
                { "find", () => search.grab_focus_entry () },
                { "category", on_category, "s" },
                { "toggle-sidebar", () => set_sidebar_visible (!get_sidebar_visible ()) },
                { "close", () => close () }
            };
            add_action_entries (entries, this);
            sync_item_actions ();

            current = app.recent ().length > 0 ? "recent" : "smileys";
            refresh ();
        }

        private Category[] categories () {
            return {
                { "recent", _("Recently Used"), "emoji-recent-symbolic" },
                { "smileys", _("Smileys & Emotion"), "emoji-people-symbolic" },
                { "people", _("People & Body"), "emoji-body-symbolic" },
                { "nature", _("Animals & Nature"), "emoji-nature-symbolic" },
                { "food", _("Food & Drink"), "emoji-food-symbolic" },
                { "travel", _("Travel & Places"), "emoji-travel-symbolic" },
                { "activities", _("Activities"), "emoji-activities-symbolic" },
                { "objects", _("Objects"), "emoji-objects-symbolic" },
                { "symbols", _("Symbols"), "emoji-symbols-symbolic" },
                { "flags", _("Flags"), "emoji-flags-symbolic" },
                { "punctuation", _("Punctuation"), "characters-punctuation-symbolic" },
                { "arrows", _("Arrows"), "characters-arrows-symbolic" },
                { "math", _("Math"), "characters-math-symbolic" },
                { "currency", _("Currency"), "characters-currency-symbolic" },
                { "letterlike", _("Letterlike"), "characters-letterlike-symbolic" },
                { "technical", _("Shapes & Technical"), "characters-technical-symbolic" },
                { "latin", _("Latin"), "characters-latin-symbolic" },
                { "greek", _("Greek"), "characters-greek-symbolic" },
                { "cyrillic", _("Cyrillic"), "characters-cyrillic-symbolic" }
            };
        }

        private void build_sidebar () {
            var cats = categories ();
            for (int i = 0; i < cats.length; i++) {
                if (i == 1) sidebar.box.append (new SidebarSectionLabel (_("Emoji")));
                if (i == 10) sidebar.box.append (new SidebarSectionLabel (_("Symbols")));
                if (i == 16) sidebar.box.append (new SidebarSectionLabel (_("Letters")));
                var row = new SidebarRow (cats[i].icon, cats[i].label);
                string id = cats[i].id;
                row.clicked.connect (() => {
                    current = id;
                    query = "";
                    refresh ();
                });
                rows[id] = row;
                sidebar.box.append (row);
            }
        }

        private void on_category (SimpleAction action, Variant? value) {
            string id = value.get_string ();
            if (!rows.has_key (id)) return;
            current = id;
            query = "";
            refresh ();
        }

        public void search_for (string text) {
            search.entry.text = text;
            query = text;
            refresh ();
        }

        public void reveal (CharItem item) {
            pending_reveal = item;
            search_for (item.text);
        }

        private void select_pending () {
            if (pending_reveal == null) return;
            if (query != pending_reveal.text) {
                pending_reveal = null;
                return;
            }
            for (uint i = 0; i < store.get_n_items (); i++) {
                if (((CharItem) store.get_item (i)).text == pending_reveal.text) {
                    selection.selected = i;
                    return;
                }
            }
        }

        private void sync_item_actions () {
            foreach (string name in new string[] { "copy", "copy-code" }) {
                var action = lookup_action (name) as SimpleAction;
                if (action != null) action.set_enabled (shown != null);
            }
        }

        private void copy_shown_code () {
            if (shown == null) return;
            get_clipboard ().set_text (shown.code_label ());
            flash (_("Copied %s").printf (shown.code_label ()));
        }

        private string label_for (string id) {
            foreach (var c in categories ()) if (c.id == id) return c.label;
            return "";
        }

        private void refresh () {
            foreach (var entry in rows.entries) entry.value.set_active (query == "" && entry.key == current);
            Gee.List<CharItem> items;
            if (query.strip () != "") {
                items = db.search (query);
                title.label = _("Results");
                subtitle.label = items.size >= 400 ? _("Showing the first 400 matches") : ngettext ("%d character", "%d characters", items.size).printf (items.size);
            } else if (current == "recent") {
                items = new Gee.ArrayList<CharItem> ();
                foreach (string t in app.recent ()) {
                    var item = db.by_text (t);
                    if (item != null) items.add (item);
                }
                title.label = label_for (current);
                subtitle.label = items.size == 0 ? _("Characters you copy appear here") : ngettext ("%d character", "%d characters", items.size).printf (items.size);
            } else {
                items = db.category (current);
                title.label = label_for (current);
                subtitle.label = ngettext ("%d character", "%d characters", items.size).printf (items.size);
            }
            selection.selected = Gtk.INVALID_LIST_POSITION;
            store.remove_all ();
            var array = new Object[items.size];
            for (int i = 0; i < items.size; i++) array[i] = items[i];
            store.splice (0, 0, array);
            bool never_used = items.size == 0 && current == "recent" && query.strip () == "";
            header.visible = !never_used;
            stack.visible_child_name = never_used ? "recent-empty" : items.size == 0 ? "empty" : "grid";
            if (items.size > 0) grid.scroll_to (0, ListScrollFlags.NONE, null);
            select_pending ();
        }

        private Widget build_recent_empty () {
            var wp = new WelcomePage ();
            wp.is_section = true;
            wp.app_icon_name = "document-open-recent";
            wp.title = _("Nothing Used Yet");
            wp.subtitle = _("Characters you copy show up here. Double-click a character or press Enter to copy it.");
            wp.add_action ("dev.sinty.characters", _("Browse Emoji"), _("Smileys, people, animals, food and more"), () => show_category ("smileys"));
            wp.add_action ("font-x-generic", _("Browse Symbols"), _("Punctuation, arrows, math and currency signs"), () => show_category ("punctuation"));
            wp.add_action ("system-search", _("Search Characters"), _("Find a character by name or by a code such as U+263A"), () => search.grab_focus_entry ());
            return wp;
        }

        private void show_category (string id) {
            if (!rows.has_key (id)) return;
            current = id;
            query = "";
            search.entry.text = "";
            refresh ();
        }

        private Widget build_panel () {
            var outer = new Box (Orientation.VERTICAL, 0);
            outer.set_size_request (300, -1);
            outer.margin_end = 16;
            outer.margin_bottom = 16;
            Singularity.Widgets.apply_view_edge (outer);
            var panel = new Box (Orientation.VERTICAL, 12);
            panel.add_css_class ("characters-panel");
            panel.vexpand = true;

            hero = new Label ("");
            hero.add_css_class ("characters-hero");
            hero.set_size_request (-1, 170);
            hero.selectable = true;
            panel.append (hero);

            char_name = new Label ("");
            char_name.add_css_class ("title-4");
            char_name.wrap = true;
            char_name.justify = Justification.CENTER;
            char_name.max_width_chars = 24;
            panel.append (char_name);

            char_code = new Label ("");
            char_code.add_css_class ("characters-code");
            char_code.add_css_class ("dim-label");
            char_code.selectable = true;
            panel.append (char_code);

            char_group = new Label ("");
            char_group.add_css_class ("characters-chip");
            char_group.halign = Align.CENTER;
            panel.append (char_group);

            variants_title = new Label (_("Skin Tones"));
            variants_title.xalign = 0;
            variants_title.add_css_class ("heading");
            variants_title.margin_top = 6;
            panel.append (variants_title);
            variants = new FlowBox ();
            variants.selection_mode = SelectionMode.NONE;
            variants.max_children_per_line = 6;
            variants.column_spacing = 4;
            variants.row_spacing = 4;
            panel.append (variants);

            case_button = new Button ();
            case_button.add_css_class ("flat");
            case_button.halign = Align.CENTER;
            case_button.clicked.connect (() => {
                var pair = shown != null ? shown.case_pair () : null;
                if (pair != null) show_item (pair);
            });
            panel.append (case_button);

            var spacer = new Box (Orientation.VERTICAL, 0);
            spacer.vexpand = true;
            panel.append (spacer);

            var copy_button = new Button.with_label (_("Copy Character"));
            copy_button.add_css_class ("suggested-action");
            copy_button.add_css_class ("pill");
            copy_button.clicked.connect (() => {
                if (shown != null) copy (shown);
            });
            panel.append (copy_button);
            var copy_code = new Button.with_label (_("Copy Code"));
            copy_code.add_css_class ("flat");
            copy_code.clicked.connect (() => copy_shown_code ());
            panel.append (copy_code);
            var share_button = new Button.with_label (_("Share…"));
            share_button.add_css_class ("flat");
            share_button.clicked.connect (() => {
                if (shown != null) Singularity.Share.text ((Gtk.Window) get_root (), shown.text, _("Character"));
            });
            panel.append (share_button);
            outer.append (panel);
            return outer;
        }

        private void on_selected () {
            var item = selection.selected_item as CharItem;
            if (item == null) {
                panel_revealer.reveal_child = false;
                shown = null;
                sync_item_actions ();
                return;
            }
            show_item (item);
        }

        private void show_item (CharItem item) {
            shown = item;
            sync_item_actions ();
            hero.label = item.text;
            char_name.label = item.display_name ();
            char_code.label = item.code_label ();
            string group = label_for (item.category);
            char_group.label = group;
            char_group.visible = group != "";
            Widget? child;
            while ((child = variants.get_first_child ()) != null) variants.remove (child);
            foreach (var v in item.variants) {
                var b = new Button.with_label (v.text);
                b.add_css_class ("flat");
                b.add_css_class ("characters-variant");
                b.tooltip_text = v.display_name ();
                var cap = v;
                b.clicked.connect (() => copy (cap));
                variants.append (b);
            }
            variants.visible = item.variants.size > 0;
            variants_title.visible = item.variants.size > 0;
            var pair = item.case_pair ();
            case_button.visible = pair != null;
            if (pair != null) {
                case_button.label = pair.text.up () == pair.text ? _("Uppercase: %s").printf (pair.text) : _("Lowercase: %s").printf (pair.text);
            }
            panel_revealer.reveal_child = true;
        }

        private void copy (CharItem item) {
            get_clipboard ().set_text (item.text);
            app.add_recent (item.text);
            flash (_("Copied %s").printf (item.text));
            if (current == "recent" && query == "") {
                uint pos = selection.selected;
                refresh ();
                if (pos != Gtk.INVALID_LIST_POSITION) selection.selected = 0;
            }
        }

        private void flash (string text) {
            copied.label = text;
            copied.visible = true;
            if (copied_source != 0) Source.remove (copied_source);
            copied_source = Timeout.add (1600, () => {
                copied.visible = false;
                copied_source = 0;
                return Source.REMOVE;
            });
        }
    }
}
