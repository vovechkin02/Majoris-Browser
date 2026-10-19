import datetime,importlib.util,json,os,pathlib,runpy,subprocess,tempfile,unittest
ENGINE=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('release_record',ENGINE/'scripts/release-record.py')
release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)

class ReleaseTests(unittest.TestCase):
    def test_approvals_are_explicit_and_bound_to_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder);(root/'Release').mkdir();(root/'include').mkdir()
            library=root/'Release/libcef.so';library.write_bytes(b'unit fixture, not an engine')
            runtime_files=runpy.run_path(str(ENGINE/'scripts/runtime-files.py'))
            for name in runtime_files['LIBRARIES']:
                if name!='libcef.so':(root/'Release'/name).write_bytes(b'fixture')
            (root/'Resources').mkdir()
            for name in ('icudtl.dat','resources.pak'):(root/'Resources'/name).write_bytes(b'fixture')
            for name in ('LICENSE.txt','CREDITS.html'):(root/name).write_text('fixture')
            (root/'include/cef_version.h').write_text('#define CEF_VERSION "fixture"\n')
            manifest=json.loads((ENGINE/'manifests/m152.json').read_text())
            metadata={'schema':1,'development_codecs':True,'source':manifest,'configuration':'fixture','workflow_sha256':'fixture','libcef_sha256':release.digest(library)}
            metadata['runtime_files']=runtime_files['inventory'](root)
            (root/'majoris-runtime.json').write_text(json.dumps(metadata))
            record=release.draft(root)
            self.assertFalse(any(record[k]['approved'] for k in ('security','runtime','redistribution','production')))
            with self.assertRaises(ValueError):release.validate(record,root,'production')
            # Synthetic approvals exercise validation, never approve real code.
            evidence=root/'evidence';evidence.write_text('unit fixture evidence')
            proof={'path':str(evidence),'sha256':release.digest(evidence)};record['channel']='production'
            for gate in ('security','runtime','redistribution','production'):record[gate].update(approved=True,reviewer='unit-test-only',authorisation_reference='fixture-not-authorisation')
            record['security'].update(reviewed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),assessment=proof)
            record['runtime']['evidence']=[proof];release.validate(record,root,'production')
            resource=root/'Resources/resources.pak';resource.write_bytes(b'mixed runtime resource')
            with self.assertRaises(ValueError):release.validate(record,root,'production')
            resource.write_bytes(b'fixture')
            extra=root/'Resources/unexpected.pak';extra.write_bytes(b'unrecorded input')
            with self.assertRaises(ValueError):release.identity(root)
            extra.unlink()
            evidence.write_text('changed')
            with self.assertRaises(ValueError):release.validate(record,root,'production')
            command=['python3',str(ENGINE/'scripts/verify-sdk.py'),'--sdk',str(root),'--for-package']
            result=subprocess.run(command,env=dict(os.environ,MAJORIS_RELEASE_CHANNEL='production',MAJORIS_DEVELOPMENT_ENGINE='1'),capture_output=True)
            self.assertNotEqual(result.returncode,0)
            library.write_bytes(b'tampered')
            with self.assertRaises(ValueError):release.identity(root)

if __name__=='__main__':unittest.main()
