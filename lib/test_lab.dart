part of 'main.dart';

extension TestLab on _EBuLaScreenState {
  Future<Map<String, dynamic>> _testUrl(String host, int port, String path) async {
    final sw = Stopwatch()..start();
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.get(host, port, path);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 4));
      final body = await res.transform(utf8.decoder).join();
      sw.stop();
      client.close(force: true);
      return {
        'ok': res.statusCode >= 200 && res.statusCode < 300,
        'status': res.statusCode,
        'ms': sw.elapsedMilliseconds,
        'body': body,
      };
    } catch (e) {
      sw.stop();
      client.close(force: true);
      return {'ok': false, 'status': 0, 'ms': sw.elapsedMilliseconds, 'error': e.toString()};
    }
  }

  Future<void> showTestLab() async {
    final hostCtrl = TextEditingController(text: bridgeHost);
    final portCtrl = TextEditingController(text: bridgePort.toString());
    bool running = false;
    final results = <String, String>{};

    Future<void> runTests(void Function(void Function()) setLocal) async {
      final host = hostCtrl.text.trim();
      final port = int.tryParse(portCtrl.text.trim()) ?? 8080;
      if (host.isEmpty) return;
      setLocal(() {
        running = true;
        results.clear();
      });
      final root = await _testUrl(host, port, '/');
      setLocal(() {
        results['TCP / HTTP'] = root['ok'] == true
            ? 'OK · ${root['status']} · ${root['ms']} ms'
            : 'FEHLER · ${root['error'] ?? 'HTTP ${root['status']}'}';
      });
      final health = await _testUrl(host, port, '/health');
      setLocal(() {
        results['Bridge /health'] = health['ok'] == true
            ? 'OK · ${health['body']}'
            : 'FEHLER · ${health['error'] ?? 'HTTP ${health['status']}'}';
      });
      final state = await _testUrl(host, port, '/api/state');
      setLocal(() {
        results['EBuLa /api/state'] = state['ok'] == true
            ? 'OK · Daten empfangen (${state['ms']} ms)'
            : 'FEHLER · ${state['error'] ?? 'HTTP ${state['status']}'}';
        running = false;
      });
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          backgroundColor: const Color(0xff17191a),
          title: const Text('Test Lab – Verbindung', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tablet → PC → Pure EBuLa Bridge', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: hostCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'PC-IP / Hostname', labelStyle: TextStyle(color: Colors.white70)))),
                  const SizedBox(width: 10),
                  SizedBox(width: 100, child: TextField(controller: portCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Port', labelStyle: TextStyle(color: Colors.white70)))),
                ]),
                const SizedBox(height: 14),
                for (final e in results.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${e.key}:\n${e.value}', style: TextStyle(color: e.value.startsWith('OK') ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10)),
                  ),
                if (results.isEmpty) const Text('Noch kein Test ausgeführt.', style: TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 6),
                const Text('Der Test verändert weder Fahrplan noch EBuLa-Darstellung.', style: TextStyle(color: Colors.white38, fontSize: 9)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: running ? null : () => runTests(setLocal), child: Text(running ? 'TEST LÄUFT …' : 'TEST STARTEN')),
            TextButton(onPressed: running ? null : () => Navigator.pop(c), child: const Text('SCHLIESSEN')),
          ],
        ),
      ),
    );
  }
}
