## Jellyfish 2.4

### Neu
- **Weitere Zeitformate**: Neue Platzhalter für amerikanisches Datum (`{MM/TT/JJJJ}`, `{MM/TT/JJ}`), ISO 8601 komplett (`{JJJJ-MM-TT HH:MM:SS}`), 12h-Format (`{hh:MM AM/PM}`) sowie einzelne Zeitkomponenten (`{HH}`, `{Min}`, `{Sek}`), Kalenderwoche (`{KW}`) und Quartal (`{Q}`)

## Jellyfish 2.3

### Verbesserungen
- **Pulldown-Snippets: Tastatursteuerung**: Das Auswahlmenü öffnet sich beim Erscheinen des Dialogs automatisch — direkt mit Pfeiltasten navigieren und mit Enter bestätigen, ohne die Maus anzufassen

## Jellyfish 2.2

### Neu
- **Formatierter Text**: Textbausteine können jetzt als „Formatierter Text" angelegt werden — mit Fett, Kursiv, Unterstrichen und Links. Umschalten über das „Inhaltstyp"-Dropdown im Editor
- **Optionaler Block: Standard-Zustand**: Beim Anlegen eines optionalen Blocks kann jetzt festgelegt werden, ob er im Vorschau-Dialog standardmäßig aktiv oder inaktiv ist (`{optional:off:Label}` für default-aus)

### Verbesserungen
- Alle Platzhalter (Datum, Uhrzeit, Rechnung, Zwischenablage, Dropdown, optionale Blöcke) funktionieren jetzt auch in formatierten Textbausteinen
- URL-Dropdowns fügen Links mit lesbarem Anzeige-Text ein — kompatibel mit TinyMCE und anderen RTF-basierten Editoren (z. B. Awesome Support)

## Jellyfish 2.1.1

### Bugfixes
- Optionaler Block: Text erscheint jetzt korrekt in der Vorschau, wenn die Checkbox aktiviert ist
- Dropdown-Dialog: Einfüge-Position wird beim Öffnen des Dialogs gespeichert — verhindert, dass ein zweites Dropdown das erste überschreibt

### Verbesserungen
- Dialog „Optionaler Block": Beschriftung von „Label" auf „Text" geändert, mehrzeiliges Eingabefeld für längere Texte, veraltete Dropdown-Gruppen-Verknüpfung entfernt
- Dropdown-Dialog: Gruppen-Feld entfernt (Bedingte Texte sind über den f(x)-Dialog verfügbar)

## Jellyfish 2.1

### Bugfixes
- Warnung beim Versuch, persönlichen Sync-Ordner und Team-Ordner auf denselben Pfad zu setzen — verhindert doppelte JSON-Dateien im geteilten Ordner

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
