"""Offline structural checks, not a substitute for an Xcode archive/device test."""
import plistlib
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
plist = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
options = (root / 'lib/firebase_options.dart').read_text(encoding='utf-8')
ios = options.split('static const FirebaseOptions ios = FirebaseOptions(')[1].split(');')[0]
client = re.search(r"iosClientId: '([^']+)'", ios)[1]
bundle = re.search(r"iosBundleId: '([^']+)'", ios)[1]
schemes = [scheme for entry in plist['CFBundleURLTypes'] for scheme in entry['CFBundleURLSchemes']]
assert '.'.join(reversed(client.split('.'))) in schemes
assert bundle == 'com.depar.app'
for key in ['NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription', 'NSLocationWhenInUseUsageDescription']:
    assert len(plist[key]) > 30
assert 'NSPhotoLibraryAddUsageDescription' not in plist
assert 'NSLocationAlwaysAndWhenInUseUsageDescription' not in plist
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
assert project.count('INFOPLIST_FILE = Runner/Info.plist;') == 3
assert project.count('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;') == 3
assert project.count('PRODUCT_BUNDLE_IDENTIFIER = com.depar.app;') == 3
assert 'PrivacyInfo.xcprivacy in Resources' in project.split('/* Begin PBXResourcesBuildPhase section */')[1]
entitlements = plistlib.loads((root / 'ios/Runner/Runner.entitlements').read_bytes())
assert entitlements['com.apple.developer.applesignin'] == ['Default']
manifest = plistlib.loads((root / 'ios/Runner/PrivacyInfo.xcprivacy').read_bytes())
assert manifest['NSPrivacyTracking'] is False
assert manifest['NSPrivacyAccessedAPITypes'] == []
assert len(manifest['NSPrivacyCollectedDataTypes']) == 9
assert 'DefaultFirebaseOptions.currentPlatform' in (root / 'lib/main.dart').read_text()
for path in (root / 'lib').rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    assert 'bizimuygulama.com' not in text, path
    assert 'halisaha.app/join' not in text, path
print('PASS: plist syntax, permissions, Firebase client/bundle/scheme, entitlements, resource membership and share URLs')
