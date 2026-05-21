## Neu in 0.0.5

### Auto-Update
„Nach Updates suchen…" im Statusleisten-Menü prüft GitHub auf neue Versionen und installiert das Update automatisch – genau wie bei UnquarantineApp.

### Bugfix: Berechtigungen werden jetzt gespeichert
Input-Monitoring-Berechtigung musste bisher bei jedem Start neu erteilt werden. Behoben.

### Snippet-Liste aus Statusleisten-Menü entfernt
Das Menü zeigt nur noch Aktionen, keine Snippet-Vorschau mehr.

### Einsetzen (Cmd+V) im Texteditor
Einfügen aus der Zwischenablage funktioniert jetzt im Snippet-Editor.

### Icons für Zeitstempel und Dropdown
Die Buttons wurden durch Material Design Icons ersetzt und zwischen „Inhaltstyp" und dem Textfeld positioniert.

---

## Neu in 0.0.4

### Bugfix: App startet nicht (0.0.3)
Ressourcen-Bundle wurde beim Start nicht gefunden — App crashte sofort. Behoben.

---

## Neu in 0.0.3

### Verteilung als DMG
Jellyfish wird jetzt als DMG ausgeliefert. Einmalig öffnen, in den Applications-Ordner ziehen, fertig – keine Quarantine-Probleme mehr. Auto-Updates entfallen; neue Versionen über „Releases auf GitHub…" im Statusleisten-Menü verfügbar.

---

## Änderungen seit 0.0.1

### Ordner
Textbausteine lassen sich in Ordner organisieren, umbenennen und per Drag & Drop verschieben.

### Datum-Platzhalter
`{TT.MM.JJJJ}`, `{HH:MM}`, `{HH:MM:SS}` u. a. werden beim Einfügen automatisch aufgelöst. Über den **Zeitstempel**-Button im Editor einfügen.

### Dropdown-Platzhalter
`{AUSWAHL:Option1|Option2|Option3}` zeigt beim Auslösen ein schwebendes Auswahlfenster mit Live-Vorschau. Optionen im Editor über den **Dropdown**-Button mit `+`/`−` verwalten.

### Bugfix: Überlappende Kürzel
Bei überlappenden Kürzeln gewinnt jetzt immer das längste.
