import hashlib
import json
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


CASES = [
    ("Nokia Classic 240", "Vendor A", "MIDP-2.0", "CLDC-1.1", "240x320"),
    ("Nokia Series 40", "Vendor B", "MIDP-2.0", "CLDC-1.1", "176x208"),
    ("Sony Ericsson K", "Vendor C", "MIDP-2.0", "CLDC-1.1", "176x220"),
    ("Motorola V", "Vendor D", "MIDP-1.0", "CLDC-1.0", "128x160"),
    ("Folded Manifest", "Vendor E", "MIDP-2.0", "CLDC-1.1", "240x320"),
    ("Manifest Icon", "Vendor F", "MIDP-2.0", "CLDC-1.1", "176x220"),
    ("MIDlet Icon Fallback", "Vendor G", "MIDP-1.0", "CLDC-1.0", "128x160"),
    ("中文游戏", "中文厂商", "MIDP-2.0", "CLDC-1.1", "240x320"),
    ("Landscape Canvas", "Vendor I", "MIDP-2.0", "CLDC-1.1", "320x240"),
    ("Default Canvas", "Vendor J", "MIDP-1.0", "CLDC-1.0", "240x320"),
]


def fixture_manifest(case):
    name, vendor, profile, configuration, resolution = case
    return (
        "Manifest-Version: 1.0\r\n"
        f"MIDlet-Name: {name}\r\n"
        f"MIDlet-Vendor: {vendor}\r\n"
        "MIDlet-Version: 1.0.0\r\n"
        f"MicroEdition-Profile: {profile}\r\n"
        f"MicroEdition-Configuration: {configuration}\r\n"
        f"Nokia-MIDlet-Canvas-Size: {resolution}\r\n"
        f"MIDlet-1: {name}, /icon.png, example.MainMIDlet\r\n\r\n"
    ).encode("utf-8")


class JavaPocketProjectTests(unittest.TestCase):
    def test_ten_import_fixtures_are_valid_jars(self):
        self.assertEqual(len(CASES), 10)
        with tempfile.TemporaryDirectory() as directory:
            for index, case in enumerate(CASES):
                jar = Path(directory) / f"fixture-{index}.jar"
                with zipfile.ZipFile(jar, "w", zipfile.ZIP_DEFLATED) as archive:
                    archive.writestr("META-INF/MANIFEST.MF", fixture_manifest(case))
                    archive.writestr("icon.png", b"\x89PNG\r\n\x1a\n")
                with zipfile.ZipFile(jar) as archive:
                    manifest = archive.read("META-INF/MANIFEST.MF").decode("utf-8")
                    self.assertIn(f"MIDlet-Name: {case[0]}", manifest)
                    self.assertIn(f"Nokia-MIDlet-Canvas-Size: {case[4]}", manifest)

    def test_app_identity_and_jar_document_type(self):
        with (ROOT / "JavaPocket/Resources/Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
        self.assertEqual(info["CFBundleDisplayName"], "JavaPocket")
        self.assertIn("jar", json.dumps(info))

    def test_feature_modules_and_storage_contract(self):
        for feature in ("App", "Library", "Import", "Player", "Controller", "Emulator", "Storage"):
            self.assertTrue((ROOT / "JavaPocket/Sources" / feature).is_dir(), feature)
        storage = (ROOT / "JavaPocket/Sources/Storage/GameStorage.swift").read_text(encoding="utf-8")
        for value in ('"Games"', '"game.jar"', '"metadata.json"', '"save"', '"rms.zip"'):
            self.assertIn(value, storage)

    def test_files_import_is_coordinated_and_reports_progress(self):
        importer = (ROOT / "JavaPocket/Sources/Import/GameImportService.swift").read_text(encoding="utf-8")
        library = (ROOT / "JavaPocket/Sources/Library/GameLibraryView.swift").read_text(encoding="utf-8")
        store = (ROOT / "JavaPocket/Sources/Library/GameLibraryStore.swift").read_text(encoding="utf-8")
        self.assertIn("NSFileCoordinator", importer)
        self.assertIn(".incoming-", importer)
        self.assertIn('exportedAs: "com.javapocket.j2me-archive"', library)
        self.assertIn("isImporting", store)
        self.assertIn("正在导入 JAR", library)

    def test_files_shared_games_folder_discovers_loose_jars(self):
        storage = (ROOT / "JavaPocket/Sources/Storage/GameStorage.swift").read_text(encoding="utf-8")
        store = (ROOT / "JavaPocket/Sources/Library/GameLibraryStore.swift").read_text(encoding="utf-8")
        app = (ROOT / "JavaPocket/Sources/App/JavaPocketApp.swift").read_text(encoding="utf-8")
        self.assertIn("func looseJARs()", storage)
        self.assertIn("func consumeLooseJAR", storage)
        self.assertIn("storage.looseJARs()", store)
        self.assertIn("scenePhase", app)

    def test_j2me_runtime_assets_and_api(self):
        expected = {
            "System.core/freej2me/libmidi/libmidi.wasm":
                "ceb1f1ad33e3e7db68fbbd184c3686abbdaf125477ca2a53c1ddf99444c1be99",
            "System.core/freej2me/libmedia/transcode/transcode.wasm":
                "a8831d65180feea3ad3a05911c5197a4ce7fd34e0b5d14e5db038ea9c45c0d5b",
            "System.core/j2mejs/java/classes.jar":
                "6745b63ac881232b5fe20a3dc2def2f3e7a7a97cbb2a8466bc999fd51af2a475",
        }
        for relative, digest in expected.items():
            self.assertEqual(hashlib.sha256((ROOT / relative).read_bytes()).hexdigest(), digest)
        html = (ROOT / "System.core/freej2me/index.html").read_text(encoding="utf-8")
        for api in ("openJar", "getSaveData", "loadSaveData", "pressKey", "releaseKey"):
            self.assertIn(api, html)
        j2mejs = (ROOT / "System.core/j2mejs/index.html").read_text(encoding="utf-8")
        for api in ("window.j2me", "openJar", "getSaveData", "loadSaveData", "window.Input"):
            self.assertIn(api, j2mejs)
        server = (ROOT / "JavaPocket/Sources/Emulator/J2MELocalServer.swift").read_text(encoding="utf-8")
        self.assertIn('appendingPathComponent("j2mejs")', server)

    def test_original_manicemu_j2me_skin_and_settings_are_bundled(self):
        skin = ROOT / "JavaPocket/Resources/ManicJ2MESkin"
        expected = (
            "info.json", "iphone_edgetoedge_portrait.pdf",
            "iphone_edgetoedge_landscape.pdf", "iphone_standard_portrait.pdf",
            "iphone_standard_landscape.pdf", "dpad.pdf", "thumbstick.pdf",
            "softkeyLeft_button.pdf", "softkeyRight_button.pdf",
            "num0_button.pdf", "star_button.pdf", "pound_button.pdf",
        )
        for filename in expected:
            self.assertGreater((skin / filename).stat().st_size, 1000, filename)
        settings = (ROOT / "JavaPocket/Sources/Library/J2MESettingsView.swift").read_text(encoding="utf-8")
        for resolution in ("96, 65", "176, 208", "176, 220", "240, 320", "360, 640"):
            self.assertIn(resolution, settings)
        player = (ROOT / "JavaPocket/Sources/Player/PlayerView.swift").read_text(encoding="utf-8")
        self.assertIn("ManicJ2MESkinView", player)

    def test_xcode_project_isolated_target(self):
        project = (ROOT / "ManicEmu/ManicEmu.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
        root_targets = project.split("targets = (", 1)[1].split(");", 1)[0]
        self.assertIn("JavaPocket", root_targets)
        self.assertNotIn("ManicEmuRelease", root_targets)
        self.assertIn("com.javapocket.emulator", project)
        self.assertIn("../JavaPocket/Resources/Info.plist", project)
        self.assertIn("../System.core/freej2me", project)


if __name__ == "__main__":
    unittest.main()
