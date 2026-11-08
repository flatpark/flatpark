import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('sync', ROOT / 'scripts/sync-upstream-metainfo.py')
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)
LOCAL = '''<component type="desktop-application"><id>io.flatpark.up</id><name>Up</name><summary>Old summary</summary><metadata_license>CC0-1.0</metadata_license><project_license>MIT</project_license><launchable type="desktop-id">io.flatpark.up.desktop</launchable><url type="homepage">https://example.org</url><description><p>Old presentation of this fixture application used for tests.</p></description><categories><category>Office</category></categories><custom><value key="flatpark">keep</value></custom><releases><release version="1.0" date="2026-01-01"><description/></release></releases></component>'''
UPSTREAM = '''<component type="desktop-application"><id>io.flatpark.up</id><name>Must not replace</name><summary>New summary</summary><metadata_license>CC0-1.0</metadata_license><project_license>MIT</project_license><launchable type="desktop-id">io.flatpark.up.desktop</launchable><url type="homepage">https://example.org</url><description><p>New presentation of this fixture application used for tests.</p><p xml:lang="es">Descripción nueva de la aplicación de ejemplo utilizada en las pruebas.</p></description><branding><color type="primary" scheme_preference="light">#E4F2E8</color><color type="primary" scheme_preference="dark">#1B3327</color></branding><categories><category>Utility</category></categories><releases><release version="1.0" date="2026-01-01" type="development"><url type="details">https://example.org/release</url><description><p>Added an editing feature.</p><p xml:lang="es">Añade una función de edición.</p></description></release></releases></component>'''


class ImportTests(unittest.TestCase):
    def test_copy_presentation_keep_distribution_fields_and_fill_notes(self):
        merged = ET.fromstring(sync.merge(LOCAL, UPSTREAM, '1.0', '<description><p>Distribution-specific installation details.</p></description>'))
        self.assertEqual(merged.findtext('summary'), 'New summary')
        self.assertEqual(merged.findtext('name'), 'Up')
        self.assertEqual(merged.findtext('categories/category'), 'Office')
        self.assertEqual(merged.findtext('custom/value'), 'keep')
        self.assertEqual(len(merged.findall('description/p')), 3)
        self.assertEqual(merged.findtext('releases/release/description/p'), 'Added an editing feature.')
        self.assertEqual(merged.find('releases/release').get('type'), 'development')
        self.assertEqual(len(merged.findall('branding/color')), 2)

    def test_idempotence_and_no_unpublished_future_release(self):
        first = sync.merge(LOCAL, UPSTREAM, '1.0')
        self.assertEqual(first, sync.merge(first, UPSTREAM, '1.0'))
        with self.assertRaises(ValueError):
            sync.merge(LOCAL, UPSTREAM.replace('version="1.0"', 'version="2.0"'), '1.0')
        with self.assertRaises(ValueError):
            sync.merge(LOCAL, UPSTREAM.replace('<id>io.flatpark.up</id>', '<id>io.wrong</id>'), '1.0')

    def test_empty_notes_and_entities_are_rejected(self):
        with self.assertRaises(ValueError):
            sync.merge(LOCAL, UPSTREAM.replace('<p>Added an editing feature.</p><p xml:lang="es">Añade una función de edición.</p>', ''), '1.0')
        with self.assertRaises(ValueError):
            sync.parse('<!DOCTYPE foo><component/>')

    @unittest.skipUnless(shutil.which('appstreamcli'), 'AppStream validator is required for integration checks')
    def test_same_version_refresh_noop_and_failure_without_partial_writes(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            manifest, metainfo = directory/'app.yml', directory/'app.metainfo.xml'
            digest = 'a' * 64
            manifest.write_text(f'''modules:
  - name: app
    sources:
      # BEGIN MANAGED EXTRA-DATA
      - type: extra-data
        filename: app.bin
        only-arches:
          - x86_64
        url: file:///does-not-exist.bin
        sha256: {digest}
        size: 123
      # END MANAGED EXTRA-DATA
''')
            metainfo.write_text(LOCAL)
            request = dict(version='1.0', sources=[dict(filename='app.bin',url='file:///does-not-exist.bin',sha256=digest,size=123)], upstreamMetainfo=UPSTREAM)
            def run():
                return subprocess.run([os.environ.get('NODE', 'node'), str(ROOT/'scripts/update-pins.mjs'), str(manifest), str(metainfo)],input=json.dumps(request),text=True,capture_output=True)
            original_manifest = manifest.read_bytes()
            result=run()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(manifest.read_bytes(), original_manifest)
            self.assertIn('New summary', metainfo.read_text())
            self.assertEqual(run().returncode, 10)
            # A real version bump imports the matching prose, keeps history
            # and advances pins only after the combined XML validates.
            request['version'] = '2.0'
            request['releaseDate'] = '2026-02-02'
            request['upstreamMetainfo'] = UPSTREAM.replace('version="1.0"', 'version="2.0"')
            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(ET.parse(metainfo).findall('releases/release')), 2)
            self.assertEqual(ET.parse(metainfo).find('releases/release').get('version'), '2.0')
            self.assertEqual(run().returncode, 10)
            before = metainfo.read_bytes()
            request['version']='3.0'
            request['sources'][0]['sha256']='b'*64
            result=run()
            self.assertEqual(result.returncode,1)
            self.assertEqual(metainfo.read_bytes(),before)
            self.assertEqual(manifest.read_bytes(),original_manifest)
            request['version']='2.0'
            request['upstreamMetainfo']=UPSTREAM.replace('version="1.0"', 'version="2.0"').replace('<p>New presentation of this fixture application used for tests.</p>', '<p><invalid>Invalid</invalid></p>')
            self.assertEqual(run().returncode,1)
            self.assertEqual(metainfo.read_bytes(),before)
            self.assertEqual(manifest.read_bytes(),original_manifest)


if __name__ == '__main__':
    unittest.main()
