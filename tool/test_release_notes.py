"""Release notes must match the tag and never leak adjacent release sections."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from release_notes import release_notes


PUBSPEC = "name: jira_time_tracker\nversion: 0.1.0+1\n"
CHANGELOG = """# Changelog

## [Unreleased]

### Added
- Future feature.

## [0.1.0] - 2026-10-02

### Added
- Initial desktop packages.

### Known limitations
- Mac packages are not notarized.

## [0.0.1] - 2026-09-30

### Fixed
- Older change.
"""


class ReleaseNotesTest(unittest.TestCase):
    def test_extracts_only_requested_release_including_limitations(self):
        self.assertEqual(release_notes("v0.1.0", PUBSPEC, CHANGELOG),
                         "### Added\n- Initial desktop packages.\n\n### Known limitations\n- Mac packages are not notarized.\n")
        self.assertIn("Initial desktop packages", release_notes("v0.1.0", PUBSPEC, CHANGELOG.replace("\n", "\r\n")))

    def test_rejects_invalid_release_inputs(self):
        invalid = [
            ("0.1.0", PUBSPEC, CHANGELOG),
            ("v0.2.0", PUBSPEC, CHANGELOG),
            ("v0.1.0", PUBSPEC.replace("+1", "+0"), CHANGELOG),
            ("v0.1.0", PUBSPEC, CHANGELOG.replace("[0.1.0]", "[0.2.0]")),
            ("v0.1.0", PUBSPEC, CHANGELOG + "\n## [0.1.0] - 2026-10-02\n- Duplicate.\n"),
            ("v0.1.0", PUBSPEC, CHANGELOG.replace("2026-10-02", "2026-02-30")),
            ("v0.1.0", PUBSPEC, CHANGELOG.replace("[0.1.0] - 2026-10-02", "[0.1.0]")),
            ("v0.1.0", PUBSPEC, "## [Unreleased]\n\n## [0.1.0] - 2026-10-02\n### Added\n"),
            ("v0.1.0", PUBSPEC, CHANGELOG.replace("## [Unreleased]", "## [Pending]")),
            ("v0.1.0", PUBSPEC, CHANGELOG + "\n## [Unreleased]\n"),
            ("v0.1.0", PUBSPEC, "# Empty changelog\n"),
        ]
        for tag, pubspec, changelog in invalid:
            with self.subTest(tag=tag, pubspec=pubspec, changelog=changelog):
                with self.assertRaises(ValueError):
                    release_notes(tag, pubspec, changelog)

    def test_cli_writes_utf8_notes_and_fails_without_release_entry(self):
        script = Path(__file__).with_name("release_notes.py").resolve()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text(PUBSPEC, encoding="utf-8")
            (root / "CHANGELOG.md").write_text(CHANGELOG, encoding="utf-8")
            command = [sys.executable, str(script), "v0.1.0", "--output", "notes.md"]
            result = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / "notes.md").read_text(encoding="utf-8"), release_notes("v0.1.0", PUBSPEC, CHANGELOG))
            (root / "CHANGELOG.md").write_text("## [Unreleased]\n- Pending.\n", encoding="utf-8")
            result = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Release validation failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
