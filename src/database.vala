namespace Singularity.Apps.Characters {

    public class CharItem : Object {
        public string category;
        public string subgroup;
        public string text;
        public uint32[] codepoints;
        public string name;
        public Gee.ArrayList<CharItem> variants = new Gee.ArrayList<CharItem> ();

        public bool is_emoji {
            get {
                return category == "smileys" || category == "people" || category == "nature" || category == "food"
                    || category == "travel" || category == "activities" || category == "objects" || category == "symbols"
                    || category == "flags" || category == "variant";
            }
        }

        public string display_name () {
            if (name.length == 0) return "";
            return name.substring (0, 1).up () + name.substring (1);
        }

        public string code_label () {
            var sb = new StringBuilder ();
            foreach (uint32 cp in codepoints) {
                if (cp == 0xFE0F || cp == 0x200D) continue;
                if (sb.len > 0) sb.append (" ");
                sb.append_printf ("U+%04X", cp);
            }
            return sb.str;
        }

        public CharItem? case_pair () {
            if (codepoints.length != 1) return null;
            unichar c = (unichar) codepoints[0];
            unichar other = c.isupper () ? c.tolower () : (c.islower () ? c.toupper () : c);
            if (other == c) return null;
            return Database.get_default ().by_text (other.to_string ());
        }
    }

    public class Database : Object {
        private static Database? instance = null;
        public Gee.ArrayList<CharItem> all = new Gee.ArrayList<CharItem> ();
        private Gee.HashMap<string, Gee.ArrayList<CharItem>> by_category = new Gee.HashMap<string, Gee.ArrayList<CharItem>> ();
        private Gee.HashMap<string, CharItem> index = new Gee.HashMap<string, CharItem> ();

        public static Database get_default () {
            if (instance == null) {
                instance = new Database ();
                try {
                    var bytes = resources_lookup_data ("/dev/sinty/characters/characters.tsv", ResourceLookupFlags.NONE);
                    instance.load ((string) bytes.get_data ());
                } catch (Error e) {
                    warning ("Character data missing: %s", e.message);
                }
            }
            return instance;
        }

        public static Database from_text (string text) {
            var db = new Database ();
            db.load (text);
            instance = db;
            return db;
        }

        private void load (string text) {
            var pending = new Gee.ArrayList<CharItem> ();
            var bases = new Gee.ArrayList<string> ();
            foreach (unowned string line in text.split ("\n")) {
                if (line.length == 0) continue;
                var parts = line.split ("\t");
                if (parts.length < 4) continue;
                var item = new CharItem ();
                item.category = parts[0];
                item.subgroup = parts[1];
                item.name = parts[3];
                var sb = new StringBuilder ();
                uint32[] cps = {};
                foreach (string hex in parts[2].split (" ")) {
                    uint32 cp = (uint32) uint64.parse (hex, 16);
                    cps += cp;
                    sb.append_unichar ((unichar) cp);
                }
                item.codepoints = cps;
                item.text = sb.str;
                if (item.category == "variant") {
                    pending.add (item);
                    bases.add (parts.length > 4 ? parts[4] : "");
                    continue;
                }
                all.add (item);
                if (!by_category.has_key (item.category)) by_category[item.category] = new Gee.ArrayList<CharItem> ();
                by_category[item.category].add (item);
                index[parts[2]] = item;
                if (!index.has_key (item.text)) index[item.text] = item;
            }
            for (int i = 0; i < pending.size; i++) {
                var base_item = index[bases[i]];
                if (base_item == null) {
                    var fe0f = bases[i] + " FE0F";
                    base_item = index[fe0f];
                }
                if (base_item != null) base_item.variants.add (pending[i]);
            }
        }

        public Gee.List<CharItem> category (string id) {
            return by_category.has_key (id) ? by_category[id] : new Gee.ArrayList<CharItem> ();
        }

        public CharItem? by_text (string text) {
            return index[text];
        }

        public CharItem? by_codepoints (string hex) {
            return index[hex.up ()];
        }

        private static string fold (string text) {
            return text.casefold ().strip ();
        }

        public Gee.List<CharItem> search (string query, int limit = 400) {
            var results = new Gee.ArrayList<CharItem> ();
            string q = fold (query);
            if (q.length == 0) return results;

            var direct = by_text (query.strip ());
            if (direct != null) results.add (direct);

            string hex = q;
            if (hex.has_prefix ("u+")) hex = hex.substring (2);
            else if (hex.has_prefix ("0x")) hex = hex.substring (2);
            bool is_hex = hex.length >= 2 && hex.length <= 6;
            for (int i = 0; is_hex && i < hex.length; i++) {
                if (!hex[i].isxdigit ()) is_hex = false;
            }
            if (is_hex) {
                var by_code = index[hex.up ()];
                if (by_code != null && !results.contains (by_code)) results.add (by_code);
                unichar c = (unichar) uint64.parse (hex, 16);
                if (by_code == null && c.validate () && c.isprint ()) {
                    var extra = new CharItem ();
                    extra.category = "other";
                    extra.subgroup = "";
                    extra.codepoints = { (uint32) c };
                    extra.text = c.to_string ();
                    extra.name = "U+%04X".printf ((uint) c);
                    results.add (extra);
                }
            }

            string[] words = q.split_set (" -");
            var starts = new Gee.ArrayList<CharItem> ();
            var contains = new Gee.ArrayList<CharItem> ();
            foreach (var item in all) {
                if (results.contains (item)) continue;
                string name = item.name;
                bool all_words = true;
                bool prefix = false;
                string padded = " " + name + " ";
                foreach (string w in words) {
                    if (w.length == 0) continue;
                    if (w.length <= 2) {
                        if (!padded.contains (" " + w + " ")) {
                            all_words = false;
                            break;
                        }
                        continue;
                    }
                    int at = name.index_of (w);
                    if (at < 0) {
                        all_words = false;
                        break;
                    }
                    if (at == 0 || name[at - 1] == ' ' || name[at - 1] == '-') prefix = true;
                }
                if (!all_words) continue;
                if (name == q || name.has_prefix (q + " ") || prefix) starts.add (item);
                else contains.add (item);
            }
            starts.sort ((a, b) => {
                bool ea = a.name == q, eb = b.name == q;
                if (ea != eb) return ea ? -1 : 1;
                return a.name.length - b.name.length;
            });
            foreach (var item in starts) {
                if (results.size >= limit) break;
                results.add (item);
            }
            foreach (var item in contains) {
                if (results.size >= limit) break;
                results.add (item);
            }
            return results;
        }
    }
}
