import unittest
from words import top_words


class TopWords(unittest.TestCase):
    def test_simple(self):
        self.assertEqual(top_words("Кот и пёс. Кот!", 1), [("кот", 2)])

    def test_empty(self):
        self.assertEqual(top_words("", 3), [])

    def test_case_and_punctuation(self):
        self.assertEqual(top_words("Да, да. ДА? нет", 2), [("да", 3), ("нет", 1)])


if __name__ == "__main__":
    unittest.main()
