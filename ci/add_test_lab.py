from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if "part 'test_lab.dart';" not in s:
    marker = "import 'package:flutter/services.dart';\n"
    s = s.replace(marker, marker + "\npart 'test_lab.dart';\n", 1)

# Keep the existing FSD function unchanged. The Test Lab is opened from the
# existing St bridge dialog, so the normal EBuLa layout/function keys remain intact.
if "showTestLab()" not in s:
    old = "        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('C')),\n        TextButton(onPressed:bridgeBusy?null:() async {"
    new = "        TextButton(onPressed:()=>showTestLab(),child:const Text('TEST LAB')),\n        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('C')),\n        TextButton(onPressed:bridgeBusy?null:() async {"
    s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')

manifest = Path('android/app/src/main/AndroidManifest.xml')
ms = manifest.read_text(encoding='utf-8')
if 'android.permission.INTERNET' not in ms:
    ms = ms.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET" />',
        1
    )
ms = ms.replace(
    '<application ',
    '<application android:usesCleartextTraffic="true" ',
    1
)
manifest.write_text(ms, encoding='utf-8')
