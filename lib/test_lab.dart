// ignore_for_file: library_private_types_in_public_api, sort_child_properties_last
part of 'main.dart';

extension TestLab on _EBuLaScreenState {
  Future<Map<String, dynamic>> _testUrl(String host, int port, String path) async {
    final sw = Stopwatch()..start();
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.get(host, port, path);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 4));
      final body = await response.transform(utf8.decoder).join();
      sw.stop();
      client.close(force: true);
      return {
        'ok': response.statusCode >= 200 && response.statusCode < 300,
        'status': response.statusCode,
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
    final hostController = TextEditingController(text: bridgeHost);
    final portController = TextEditingController(text: bridgePort.toString());
    bool running = false;
    final results = <String, String>{};

    Future<void> runTests(void Function(void Function()) setLocal) async {
      final host = hostController.text.trim();
      final port = int.tryParse(portController.text.trim()) ?? 8080;
      if (host.isEmpty) return;

      setLocal(() {
        running = true;
        results.clear();
      });

      final root = await _testUrl(host, port, '/');
      setLocal(() {
        results['Verbindung'] = root['ok'] == true
            ? 'OK – HTTP \${root['status']} – \${root['ms']} ms'
            : 'FEHLER – \${root['error'] ?? 'HTTP \${root['status']}'}';
      });

      final health = await _testUrl(host, port, '/health');
      setLocal(() {
        results['Bridge /health'] = health['ok'] == true
            ? 'OK – \${health['body']}'
            : 'FEHLER – \${health['error'] ?? 'HTTP \${health['status']}'}';
      });

      final state = await _testUrl(host, port, '/api/state');
      setLocal(() {
        results['EBuLa /api/state'] = state['ok'] == true
            ? 'OK – Daten empfangen – \${state['ms']} ms'
            : 'FEHLER – \${state['error'] ?? 'HTTP \${state['status']}'}';
        running = false;
      });
    }

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              backgroundColor: const Color(0xff17191a),
              title: const Text('Test Lab – Verbindung', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tablet → PC → Pure EBuLa Bridge', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: hostController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: 'PC-IP / Hostname', labelStyle: TextStyle(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: portController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: 'Port', labelStyle: TextStyle(color: Colors.white70)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (results.isEmpty)
                        const Text('Noch kein Test ausgeführt.', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      for (final entry in results.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '\${entry.key}:\\n\${entry.value}',
                            style: TextStyle(
                              color: entry.value.startsWith('OK') ? Colors.greenAccent : Colors.orangeAccent,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      const Text('Der Test verändert weder Fahrplan noch EBuLa-Darstellung.', style: TextStyle(color: Colors.white38, fontSize: 9)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: running ? null : () => runTests(setLocal),
                  child: Text(running ? 'TEST LÄUFT …' : 'TEST STARTEN'),
                ),
                TextButton(
                  onPressed: running ? null : () => Navigator.pop(dialogContext),
                  child: const Text('SCHLIESSEN'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
