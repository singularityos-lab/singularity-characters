using Singularity.Apps.Characters;

string ch (uint32 cp) {
    return ((unichar) cp).to_string ();
}

void load () {
    string text;
    try {
        FileUtils.get_contents (Environment.get_variable ("CHARACTERS_DATA"), out text);
    } catch (Error e) {
        error ("data: %s", e.message);
    }
    Database.from_text (text);
}

void test_categories () {
    var db = Database.get_default ();
    assert (db.category ("smileys").size > 100);
    assert (db.category ("latin").size > 500);
    assert (db.category ("nope").size == 0);
    var wave = db.by_text (ch (0x1F44B));
    assert (wave != null && wave.variants.size == 5);
    assert (wave.code_label () == "U+1F44B");
    var heart = db.by_text (ch (0x2764) + ch (0xFE0F));
    assert (heart != null && heart.code_label () == "U+2764");
}

void test_search () {
    var db = Database.get_default ();
    var r = db.search ("grinning face");
    assert (r.size > 0 && r[0].name == "grinning face");
    r = db.search ("U+2192");
    assert (r.size > 0 && r[0].text == ch (0x2192));
    r = db.search ("2192");
    assert (r[0].text == ch (0x2192));
    r = db.search (ch (0x20AC));
    assert (r[0].name == "euro sign");
    r = db.search ("arrow right");
    assert (r.size > 5);
    assert (db.search ("zzzqqq").size == 0);
    r = db.search ("a with grave");
    foreach (var item in r) assert ((" " + item.name + " ").contains (" a ") && item.name.contains ("grave"));
    assert (r.size >= 2 && r[0].name.has_suffix (" a with grave"));
}

void test_case_pair () {
    var db = Database.get_default ();
    var a = db.by_text (ch (0xC0));
    assert (a != null);
    var pair = a.case_pair ();
    assert (pair != null && pair.text == ch (0xE0));
    assert (db.by_text (ch (0x2192)).case_pair () == null);
    assert (a.display_name () == "Latin capital letter a with grave");
}

int main (string[] args) {
    Test.init (ref args);
    load ();
    Test.add_func ("/characters/categories", test_categories);
    Test.add_func ("/characters/search", test_search);
    Test.add_func ("/characters/case", test_case_pair);
    return Test.run ();
}
