# Pure EBuLa Bridge

Windows bridge between Train Sim World 6 and the Pure EBuLa Android app.

## Ziel

Nur EBuLa-relevante Daten:
- TSW-Verbindung
- Simulationszeit
- Position
- Richtung
- Route/Zugzuordnung (Adapter wird erweitert)
- Kilometerposition (wird aus TSW-/Streckendaten ergänzt)

Kein Tacho, PZB, LZB, MFA oder Bremsdashboard.

## TSW6

TSW6 muss seine External Interface API aktiv haben. Dazu ist derzeit der TSW-Startparameter `-HTTPAPI` erforderlich. Beim ersten Start erzeugt TSW die `CommAPIKey.txt`.

Die Bridge sucht automatisch unter:
- Documents/My Games/TrainSimWorld6/Saved/Config/CommAPIKey.txt
- Documents/My Games/TrainSimWorld6EGS/Saved/Config/CommAPIKey.txt
- zusätzlich TSW5-Pfade als Fallback

## Eigene Bridge-API

- GET /health
- GET /api/status
- GET /api/state
- GET /api/ebula
- GET /api/position
- GET /api/time

Die Android-App muss nur die Bridge-Adresse kennen.

## Start

Entweder Python:
`python bridge/pure_ebula_bridge.py`

Oder die gebaute Windows-EXE:
`PureEBuLaBridge.exe`

Die EXE benötigt keine Python-Installation.

## Hinweis

Die TSW-API ist eine REST/JSON-Schnittstelle. Die Bridge verwendet bewusst einen Adapter, der zuerst `/info` und `/list` abfragt. Damit können wir die tatsächlichen TSW6-Knoten auf dem Testsystem feststellen, bevor wir die endgültige Positions-/Kilometerzuordnung fest verdrahten.
