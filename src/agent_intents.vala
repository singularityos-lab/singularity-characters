namespace Singularity.Apps.Characters {

    internal class CharactersIntents : Object {

        private static string text(Json.Object args, string key) {
            return args.has_member(key) ? args.get_string_member(key).strip() : "";
        }

        private static void item(Json.Builder b, CharItem c) {
            b.begin_object();
            b.set_member_name("character").add_string_value(c.text);
            b.set_member_name("name").add_string_value(c.display_name());
            b.set_member_name("code").add_string_value(c.code_label());
            b.set_member_name("category").add_string_value(c.category);
            if (c.variants.size > 0) {
                b.set_member_name("variants").begin_array();
                foreach (var v in c.variants) b.add_string_value(v.text);
                b.end_array();
            }
            b.end_object();
        }

        private static CharItem find(string wanted) throws Error {
            if (wanted == "") throw new IOError.INVALID_ARGUMENT("give the character, its name or its code");
            var db = Database.get_default();
            var c = db.by_text(wanted);
            if (c != null) return c;
            string hex = wanted.up().replace("U+", "").replace("0X", "").replace(" ", "-");
            c = db.by_codepoints(hex);
            if (c != null) return c;
            var found = db.search(wanted, 50);
            string want = wanted.casefold();
            foreach (var x in found) if (x.name.casefold() == want) return x;
            if (found.size == 1) return found[0];
            if (found.size == 0) throw new IOError.NOT_FOUND("no character matches %s", wanted);
            throw new IOError.INVALID_ARGUMENT("%d characters match %s; pass the character itself from characters_search", found.size, wanted);
        }

        internal static void install(CharactersApp app) {
            var agent = app.agent;
            agent.add_intent("characters_search", "Find emoji, symbols and letters by name, keyword, the character itself or its Unicode code such as U+2192.",
                "{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\"},\"limit\":{\"type\":\"integer\"}},\"required\":[\"query\"]}",
                Singularity.AppIntentRisk.READ, (args) => {
                    string q = text(args, "query");
                    if (q == "") throw new IOError.INVALID_ARGUMENT("give what to look for");
                    int limit = args.has_member("limit") ? (int) args.get_int_member("limit").clamp(1, 100) : 20;
                    var found = Database.get_default().search(q, limit);
                    var b = new Json.Builder();
                    b.begin_object();
                    b.set_member_name("results").begin_array();
                    foreach (var c in found) item(b, c);
                    b.end_array();
                    b.end_object();
                    return b.get_root();
                });
            agent.add_intent("characters_recent", "The characters the person copied most recently, newest first.",
                "{\"type\":\"object\",\"properties\":{}}", Singularity.AppIntentRisk.READ, (args) => {
                    var db = Database.get_default();
                    var b = new Json.Builder();
                    b.begin_array();
                    foreach (string t in app.recent()) {
                        var c = db.by_text(t);
                        if (c != null) item(b, c);
                    }
                    b.end_array();
                    return b.get_root();
                });
            agent.add_intent("characters_copy", "Copy a character to the clipboard so the person can paste it, and add it to Recently Used. code copies its Unicode code instead.",
                "{\"type\":\"object\",\"properties\":{\"character\":{\"type\":\"string\"},\"code\":{\"type\":\"boolean\"}},\"required\":[\"character\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var c = find(text(args, "character"));
                    bool code = args.has_member("code") && args.get_boolean_member("code");
                    string value = code ? c.code_label() : c.text;
                    if (!code) app.add_recent(c.text);
                    if (!code && (app.recent().length == 0 || app.recent()[0] != c.text)) throw new IOError.FAILED("%s was not added to Recently Used", c.text);
                    var b = new Json.Builder();
                    b.begin_object();
                    b.set_member_name("copied").add_string_value(value);
                    b.set_member_name("name").add_string_value(c.display_name());
                    b.set_member_name("private").begin_object();
                    b.set_member_name("clipboard").begin_object();
                    b.set_member_name("text").add_string_value(value);
                    b.set_member_name("sensitive").add_boolean_value(false);
                    b.set_member_name("clear_after").add_int_value(0);
                    b.end_object();
                    b.end_object();
                    b.end_object();
                    return b.get_root();
                });
        }
    }
}
