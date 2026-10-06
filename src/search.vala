namespace Singularity.Apps.Characters {

    public class CharactersSearch : Singularity.SearchProviderService {
        private const int MAX_RESULTS = 10;
        private weak CharactersApp app;

        public CharactersSearch (CharactersApp app) {
            this.app = app;
        }

        private static string id_for (CharItem item) {
            var sb = new StringBuilder ();
            foreach (uint32 cp in item.codepoints) {
                if (sb.len > 0) sb.append (" ");
                sb.append_printf ("%X", cp);
            }
            return sb.str;
        }

        private CharItem? lookup (string id) {
            var item = Database.get_default ().by_codepoints (id);
            if (item != null) return item;
            var cps = id.split (" ");
            if (cps.length != 1) return null;
            unichar c = (unichar) uint64.parse (cps[0], 16);
            if (!c.validate () || !c.isprint ()) return null;
            var extra = new CharItem ();
            extra.category = "other";
            extra.subgroup = "";
            extra.codepoints = { (uint32) c };
            extra.text = c.to_string ();
            extra.name = "U+%04X".printf ((uint) c);
            return extra;
        }

        public override async string[] get_initial_results (string[] terms, Cancellable? cancellable) throws Error {
            string query = string.joinv (" ", terms).strip ();
            string[] ids = {};
            if (query.char_count () < 3) return ids;
            foreach (var item in Database.get_default ().search (query, MAX_RESULTS)) {
                ids += id_for (item);
            }
            return ids;
        }

        public override async Singularity.SearchResultMeta[] get_result_metas (string[] ids, Cancellable? cancellable) throws Error {
            Singularity.SearchResultMeta[] metas = {};
            foreach (string id in ids) {
                var item = lookup (id);
                if (item == null) continue;
                string name = item.display_name ();
                var meta = new Singularity.SearchResultMeta (id, name != "" ? name : item.text);
                meta.description = item.code_label ();
                meta.preview_text = item.text;
                meta.add_action ("copy", _("Copy"), "edit-copy-symbolic");
                meta.add_action ("open", _("Show in Characters"), "system-search-symbolic");
                metas += meta;
            }
            return metas;
        }

        public override async Singularity.SearchActivationReply? activate_result (string id, string[] terms, uint32 timestamp) throws Error {
            var item = lookup (id);
            if (item == null) return null;
            app.add_recent (item.text);
            return Singularity.SearchActivationReply.copy (item.text);
        }

        public override async Singularity.SearchActivationReply? activate_action (string id, string action_id, string[] terms, uint32 timestamp) throws Error {
            var item = lookup (id);
            if (item == null) return null;
            if (action_id == "open") {
                app.show_character (item);
                return null;
            }
            app.add_recent (item.text);
            return Singularity.SearchActivationReply.copy (item.text);
        }

        public override void launch_search (string[] terms, uint32 timestamp) {
            app.show_search (string.joinv (" ", terms));
        }
    }
}
