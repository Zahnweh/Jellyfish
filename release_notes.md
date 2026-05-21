## Neu in 0.0.2

### Ordner
Textbausteine lassen sich jetzt in Ordner organisieren. Ordner können über das `+`/`−`-Menü im linken Panel angelegt, umbenannt und gelöscht werden. Snippets können per Drag & Drop in Ordner verschoben werden.

### Datum-Platzhalter
Zeitstempel werden direkt im Textbaustein kodiert und beim Einfügen automatisch aufgelöst – z. B. `{TT.MM.JJJJ}`, `{HH:MM}`, `{HH:MM:SS}`. Über den **Zeitstempel**-Button im Editor lassen sich alle Formate bequem einfügen.

### Dropdown-Platzhalter
Mit `{AUSWAHL:Option1|Option2|Option3}` lassen sich Auswahlmöglichkeiten direkt im Textbaustein definieren. Beim Auslösen des Kürzels erscheint ein schwebendes Auswahlfenster mit Live-Vorschau – der aktuell gewählte Wert wird farblich hervorgehoben. Optionen können im Editor über den **Dropdown**-Button mit `+`/`−` verwaltet werden.

### Bugfix: Überlappende Kürzel
Wenn ein Kürzel auf ein anderes endet (z. B. `an#` und `ian#`), gewinnt jetzt immer das längste Kürzel.
