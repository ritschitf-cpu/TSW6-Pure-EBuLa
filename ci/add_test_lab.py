from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
if "part 'test_lab.dart';" not in s:
    marker = "import 'package:flutter/services.dart';\n"
    s = s.replace(marker, marker + "\npart 'test_lab.dart';\n", 1)
if "else if(a=='TestLab')" not in s:
    marker = "    else if(a=='St'){showBridge();}\n"
    s = s.replace(marker, marker + "    else if(a=='TestLab'){showTestLab();}\n", 1)
# Reuse the existing FSD key as a temporary, non-invasive diagnostic entry point.
s = s.replace("else if(a=='FSD'){setState(()=>overlay=overlay=='FSD'?'':'FSD');}", "else if(a=='FSD'){showTestLab();}", 1)
p.write_text(s, encoding='utf-8')

manifest = Path('android/app/src/main/AndroidManifest.xml')
ms = manifest.read_text(encoding='utf-8')
if 'android.permission.INTERNET' not in ms:
    ms = ms.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET" />', 1)
manifest.write_text(ms, encoding='utf-8')
