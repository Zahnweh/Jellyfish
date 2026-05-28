## Jellyfish 2.0

### Neu
- **Cloud-Synchronisation**: Snippets über iCloud Drive, Dropbox oder einen beliebigen Cloud-Dienst auf allen eigenen Geräten synchronisieren — einstellbar unter Einstellungen → Persönlicher Sync
- **Team-Sharing**: Einzelne Ordner selektiv mit dem Team teilen — Team-Sync-Ordner in den Einstellungen konfigurieren, dann per Rechtsklick auf einen Ordner → „Mit Team teilen". Geteilte Ordner sind in der Sidebar mit einem Team-Icon gekennzeichnet
- **Auto-Reload**: Jellyfish erkennt Änderungen durch andere Geräte oder Teammitglieder und aktualisiert die Snippet-Liste automatisch im Hintergrund, ohne Neustart

## Jellyfish 1.6

### Neu
- **Suchfeld-Dropdown**: Optionslisten mit mehr als 10 Einträgen erhalten automatisch ein Suchfeld

### Bugfixes
- Picker-Breite passt sich dynamisch der Fensterbreite an

## Jellyfish 1.5

### Neu
- **CSV-Import/Export**: Snippets als CSV exportieren und importieren
- **TextExpander-Import**: TextExpander-Gruppen direkt importieren

## Jellyfish 1.1.1

### Neu
- **Textbausteine duplizieren**: Bestehende Snippets per Kontextmenü duplizieren

### Verbesserungen
- Fehlermeldung beim Auto-Update zeigt jetzt den genauen Grund an

## Jellyfish 1.0

Erste stabile Version mit vollständigem Feature-Set.

### Neu
- **Dropdown mit bedingten Texten** (f(x)-Button): erstellt Dropdown und optionale Blöcke in einem Dialog
- **Farbkodierung** im Vorschau-Dialog: jeder optionale Block in eigener Farbe, passend zur Checkbox
- **Größeres Vorschau-Fenster**: 50 % Bildschirmbreite × 70 % Höhe
- **Gruppen-Syntax**: `{AUSWAHL:1:...}` gleichwertig zu `{AUSWAHL:G1:...}`
- **Datum-Platzhalter**: 18 Formate, Datumsrechnung, Zwischenablage
- **Optionale Blöcke**: `{optional:Label}...{/optional}`
- **Ordner** mit Unterordnern, Drag & Drop, Umbenennen
- **Suchfeld**: Live-Suche über alle Textbausteine

### Bugfixes
- Dropdowns ohne explizite Gruppe synchronisierten sich fälschlicherweise
- Textexpansion funktioniert bei GUI-Start (macOS 15+)

## Jellyfish 0.0.2

Interner Test-Release für den Auto-Updater.
