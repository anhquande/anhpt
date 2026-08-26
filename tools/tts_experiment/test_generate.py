import unittest

from generate import cache_key, cache_material, load_config, normalize_text
from pathlib import Path


class GenerateTest(unittest.TestCase):
    def test_normalize_text_uses_nfc_and_collapses_whitespace(self):
        self.assertEqual(normalize_text("  Ha\u0300ít\n  thở  "), "Hàít thở")

    def test_cache_key_is_stable_and_profile_sensitive(self):
        base = dict(text=" Nghỉ  30 giây ", language="vi-VN", profile="recovery_cue",
                    voice="marin", speed=0.92, provider="openai",
                    model="gpt-4o-mini-tts", experiment_version="vi-coach-v1")
        first = cache_key(cache_material(**base))
        base["text"] = "Nghỉ 30 giây"
        self.assertEqual(first, cache_key(cache_material(**base)))
        base["profile"] = "intense_interval"
        self.assertNotEqual(first, cache_key(cache_material(**base)))

    def test_fixture_has_three_cues_per_profile(self):
        config = load_config(Path(__file__).with_name("cues.json"))
        counts = {name: 0 for name in config["profiles"]}
        for cue in config["cues"]:
            counts[cue["profile"]] += 1
        self.assertEqual(counts, {name: 3 for name in config["profiles"]})


if __name__ == "__main__":
    unittest.main()
