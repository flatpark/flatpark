import copy
from datetime import datetime,timezone
import importlib.util
from pathlib import Path
import unittest

path=Path(__file__).with_name('resolve-release.py')
spec=importlib.util.spec_from_file_location('resolver',path);r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
NOW=datetime(2026,11,3,tzinfo=timezone.utc)


def fixture(number=1):
    version=f'4.0.0-dev-{number}-gaaaaaaaaaa-r3-qt'+('b'*16)
    base=f'https://github.com/{r.REPOSITORY}/releases/download/{version}/'
    data=dict(schema=1,channel='production',repository=r.REPOSITORY,version=version,runtime='org.kde.Platform//6.11',
              attestation_required=True,upstream_sha='a'*40,qt_abi_identity='b'*64,automated_status='PASS',known_issues=[],assets={})
    assets=[]
    for arch in ['x86_64','aarch64']:
        name=f'vlc-{version}-{arch}.tar.zst'
        data['assets'][arch]=dict(name=name,url=base+name,size=123,sha256='c'*64,verification='PASS')
        assets.append(dict(name=name,browser_download_url=base+name,state='uploaded',size=123,digest='sha256:'+'c'*64))
    assets.extend(dict(name=n,browser_download_url=base+n,size=123,state='uploaded') for n in ['release.json','provenance.intoto.jsonl'])
    rel=dict(tag_name=version,draft=False,prerelease=True,published_at=f'2026-11-0{number}T00:00:00Z',assets=assets,html_url=base)
    return rel,data


class ResolverTests(unittest.TestCase):
    def setUp(self):self.rel,self.data=fixture()
    def resolve(self,rel=None,data=None):return r.select([rel or self.rel],lambda url:data or self.data,NOW)
    def test_valid_production_prerelease_pair(self):
        result=self.resolve();self.assertEqual(len(result['sources']),2)
        self.assertEqual({s['arch'] for s in result['sources']},{'x86_64','aarch64'})
    def test_incomplete_and_draft(self):
        for field in ['missing','draft']:
            rel=copy.deepcopy(self.rel)
            if field=='missing':rel['assets'].pop(0)
            else:rel['draft']=True
            with self.assertRaises(ValueError):self.resolve(rel)
    def test_internal_prerelease_and_bad_metadata(self):
        for key,value in [('channel','internal'),('schema',99),('upstream_sha','unknown'),('assets',{}),('automated_status','FAIL')]:
            data=copy.deepcopy(self.data);data[key]=value
            with self.assertRaises(ValueError):self.resolve(data=data)
    def test_older_valid_release_selected_without_mixing(self):
        newer,data=fixture(2);newer['assets'].pop(0)
        result=r.select([newer,self.rel],lambda url:self.data,NOW)
        self.assertEqual(result['version'],self.data['version'])
        self.assertTrue(all(self.data['version'] in s['url'] for s in result['sources']))
    def test_ambiguous_or_additional_payloads_rejected(self):
        for asset in [self.rel['assets'][0],dict(name='unexpected.tar.zst')]:
            rel=copy.deepcopy(self.rel);rel['assets'].append(asset)
            with self.assertRaises(ValueError):self.resolve(rel)
    def test_diagnostic_zip_never_selected(self):
        self.rel['assets'].append(dict(name='diagnostics-aarch64.zip'))
        self.assertTrue(all(s['url'].endswith('.tar.zst') for s in self.resolve()['sources']))
    def test_digest_size_and_urls_must_agree(self):
        for key,value in [('size',999),('digest','sha256:'+'f'*64),('browser_download_url','https://example.com/latest')]:
            rel=copy.deepcopy(self.rel);rel['assets'][0][key]=value
            with self.assertRaises(ValueError):self.resolve(rel)
    def test_api_error_or_rate_limit_fails(self):
        def denied(url):raise RuntimeError('HTTP 403 rate limit')
        with self.assertRaises(RuntimeError):r.select([self.rel],denied,NOW)
        with self.assertRaises(ValueError):r.select({'message':'API error'},denied,NOW)
    def test_waiver_cannot_be_extended_or_used_after_expiry(self):
        self.data['automated_status']='WAIVED';self.data['assets']['aarch64']['verification']='WAIVED'
        self.data['known_issues']=[dict(id='VLC-X11-RAPID-QUIT-AARCH64-2026-11',architecture='aarch64',test='xcb-gui-openuri-quit-rapid',source_commit='a'*40,decision='WAIVED',exit_code=134,expires_at='2026-11-16T00:00:00Z')]
        self.assertEqual(len(self.resolve()['sources']),2)
        with self.assertRaises(ValueError):r.select([self.rel],lambda url:self.data,datetime(2026,11,16,tzinfo=timezone.utc))
        self.data['known_issues'][0]['expires_at']='2026-12-01T00:00:00Z'
        with self.assertRaises(ValueError):self.resolve()
    def test_release_json_from_before_the_transfer(self):
        legacy=r.LEGACY_REPOSITORIES[0];old=f'https://github.com/{r.REPOSITORY}/';new=f'https://github.com/{legacy}/'
        self.data['repository']=legacy
        for record in self.data['assets'].values():record['url']=record['url'].replace(old,new)
        result=self.resolve()
        self.assertTrue(all(s['url'].startswith(old) for s in result['sources']))
        # Repository and asset URLs must name the same owner.
        self.data['assets']['x86_64']['url']=self.data['assets']['x86_64']['url'].replace(new,old)
        with self.assertRaises(ValueError):self.resolve()
    def test_unknown_repository_rejected(self):
        self.data['repository']='someone-else/vlc-nightly-release'
        with self.assertRaises(ValueError):self.resolve()
        # The API side never accepts the legacy owner.
        rel=copy.deepcopy(self.rel)
        for asset in rel['assets']:asset['browser_download_url']=asset['browser_download_url'].replace(r.REPOSITORY,r.LEGACY_REPOSITORIES[0])
        with self.assertRaises(ValueError):self.resolve(rel)

if __name__=='__main__':unittest.main()
