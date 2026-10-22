# Klarsicht

Schlankes Spell-Tracking für WoW Classic und WoW Forever. Klarsicht ersetzt kein UI, sondern legt nur die Zauber-Symbole auf den Bildschirm, die du sehen willst:

- **Abklingzeit** als Spirale und Zahl (unter 3 Sekunden mit Nachkommastelle, rot)
- **Grau**, wenn das Ziel außer Reichweite ist
- **Blau**, wenn das Mana fehlt, dunkel, wenn der Zauber gerade nicht nutzbar ist
- **Leuchten** bei einem Proc (Blizzard-Leuchten), wenn der Zauber im Kampf bereit ist oder solange ein Buff aktiv ist
- **Sichtbarkeit**: immer, nur im Kampf, nur mit feindlichem Ziel; optional nur, wenn bereit oder nur während der Abklingzeit
- Größe und Position frei wählbar, pro Zauber

Die Einstellungen werden pro Charakter gespeichert (`KlarsichtCharDB`).

## Installation

Den Ordner `Klarsicht` nach `…\World of Warcraft\_classic_era_\Interface\AddOns\` kopieren (für Forever in den Forever-Spielordner). Danach im Charakter-Auswahlbildschirm unter „AddOns“ prüfen, dass Klarsicht aktiv ist.

Die TOC-Datei deckt Classic Era 1.15.9 (11509), Anniversary 2.5.6 (20506), Mists 5.5.4 (50504) und Forever 1.60.1 (16001) ab. Steht Klarsicht nach einem Patch als „veraltet“ in der Liste, im Spiel `/dump (select(4, GetBuildInfo()))` eingeben und die Zahl in `Klarsicht.toc` bei `## Interface:` ergänzen.

## Bedienung

| Befehl | Wirkung |
|---|---|
| `/ks` oder `/klarsicht` | Einstellungsfenster öffnen/schließen |
| `/ks unlock` | Symbole mit der Maus verschieben, Gitter einblenden (Rechtsklick wählt eines aus) |
| `/ks lock` | Symbole fixieren, Gitter ausblenden, Klicks gehen wieder durch |
| `/ks export` | Profil als Text zum Kopieren anzeigen |
| `/ks import` | Profil aus kopiertem Text laden |
| `/ks status` | Version, Client und Zähler für die Forever-Sonderwege im Chat ausgeben (für Testberichte) |

Das Fenster ist außerdem unter Optionen → AddOns → Klarsicht erreichbar.

**Zauber hinzufügen:** Namen oder Spell-ID eintippen und Enter drücken oder einen Zauber aus dem Zauberbuch auf das Feld „Zauber hierher ziehen“ ziehen. Bei Classic-Zaubern mit Rängen folgt Klarsicht automatisch dem höchsten gelernten Rang.

**Klassen-Vorschlag laden:** fügt die wichtigen Abklingzeiten hinzu, die der Charakter kennt, als zentrierte Reihe unter dem Charakter. Mehrfach klicken schadet nicht: Neu gelernte Zauber kommen dazu, vorhandene bleiben.

- **Magier:** Gegenzauber, Frostnova, Blinzeln, Feuerschlag, Kältekegel, Hervorrufung und Talente wie Geistesgegenwart, Arkane Macht, Verbrennung, Eisblock, Kälteeinbruch, Eisbarriere
- **Priester:** Machtwort: Schild, Gedankenschlag, Psychischer Schrei, Verblassen, die Volks-Priesterzauber (z. B. Verzweifeltes Gebet, Furchtzauberschutz, Elunes Anmut, Sternensplitter, Verschlingende Seuche) und Talente wie Heiliges Feuer, Innerer Fokus, Seele der Macht, Stille, Brunnen des Lichts
- **Alle Klassen:** die Volksfähigkeit mit Abklingzeit, z. B. Wille der Verlassenen, Steingestalt, Schattenhaftigkeit, Wachsamkeit, Berserker

### Verschieben mit Gitter

„Symbole verschieben“ (oder `/ks unlock`) blendet ein Gitter über den Bildschirm. Die goldenen Linien laufen durch die Bildschirmmitte, jede vierte Linie ist etwas heller. Beim Ziehen rastet die Mitte des Symbols am nächsten Gitterpunkt ein, und unter dem Symbol stehen die Koordinaten.

- **Alt** beim Anklicken gedrückt: alle Symbole wandern zusammen, die Abstände bleiben gleich.
- **Shift** während des Ziehens: frei schieben, ohne Einrasten.
- Unten im Fenster: Gitter anzeigen, Einrasten an/aus und die Rastergröße (8, 16, 32 oder 64 px).

Tipp: Bei 40 px großen Symbolen und 8 px Raster liegen sie lückenlos nebeneinander, bei 16 px Raster mit 8 px Abstand.

### Profile teilen

„Profil exportieren“ zeigt die ganze Liste als eine Textzeile wie `KS1:id=2139,glowReady=1,x=-88,y=-180;id=122,...:3f2a`. Mit Strg+C kopieren und irgendwo einfügen: Discord, Textdatei oder bei einem anderen Charakter über „Profil importieren“ (Strg+V).

- **Ersetzen** löscht die aktuelle Liste und übernimmt das Profil.
- **Ergänzen** fügt nur Zauber hinzu, die noch fehlen.
- Zauber werden über ihre ID übertragen, ein Profil aus einem englischen Client funktioniert also auch im deutschen. Zauber, die der Client nicht kennt, werden übersprungen. Nur Buff-Namen fürs Leuchten bleiben so, wie sie eingetippt wurden.
- Der Text enthält eine Prüfsumme. Ist er beim Kopieren abgeschnitten oder verändert worden, lehnt Klarsicht ihn ab, statt etwas Halbes zu laden. Beim Import wird nur Text gelesen, nie Code ausgeführt.

Solange das Fenster offen ist, werden alle Symbole angezeigt, auch wenn ihre Sichtbarkeitsregel sie sonst ausblenden würde. Das ausgewählte Symbol ist blau hinterlegt.

### Beispiele für Magier

Classic Era zeigt von sich aus kaum Proc-Leuchten. Für Procs ist dort „Solange dieser Buff aktiv ist“ die zuverlässigere Wahl.

- **Freizaubern sichtbar machen:** Arkane Geschosse hinzufügen, „Solange dieser Buff aktiv ist“ anhaken und `Freizaubern` (englischer Client: `Clearcasting`) eintragen.
- **Gegenzauber nie verpassen:** „Wenn bereit (im Kampf)“ anhaken und unter „Anzeigen“ „Nur mit feindlichem Ziel“ wählen.
- **Große Abklingzeiten ohne Unruhe:** Arkane Macht oder Verbrennung auf „Nur wenn bereit“ stellen. Das Symbol taucht nur auf, wenn du es zünden kannst.

### Beispiele für Priester (gut für Hardcore)

- **Notknöpfe im Blick:** Psychischer Schrei, Verblassen und Verzweifeltes Gebet auf „Nur im Kampf“ stellen und „Wenn bereit (im Kampf)“ anhaken. Sie leuchten genau dann, wenn sie dich retten können.
- **Leveln mit Gedankenschlag:** „Grau, wenn außer Reichweite“ und „Blau, wenn Mana fehlt“ zeigen auf einen Blick, ob der nächste Gedankenschlag sitzt.
- **Ruhe außerhalb des Kampfes:** Alles außer Machtwort: Schild auf „Im Kampf oder mit feindlichem Ziel“ stellen.

## WoW Forever

Forever läuft auf dem modernen Midnight-Client. Dort sind im Kampf manche Werte für Addons „geheim“. Klarsicht geht damit so um:

| Funktion | Im Kampf auf Forever |
|---|---|
| Abklingzeit-Spirale | funktioniert (über Blizzards Duration-Objekt) |
| Abklingzeit-Zahl | Blizzards eigene Countdown-Zahl statt der von Klarsicht (unabhängig von der Spieloption für Abklingzeit-Zahlen) |
| Reichweite, Mana, Proc-Leuchten | funktionieren |
| „Blasser während Abklingzeit“, „Nur wenn bereit“ | funktionieren (Blizzard gibt „aktiv ja/nein“ frei) |
| Leuchten bei Buff | kann im Kampf ausfallen, wenn Blizzard den Buff sperrt |

Getestet ist das bisher nur gegen Blizzards API-Dokumentation und einen nachgebauten Client, nicht im echten Spiel. Die Anleitung für einen Test in Forever steht in [TESTEN-FOREVER.md](TESTEN-FOREVER.md); `/ks status` zeigt danach, ob die Forever-Sonderwege gegriffen haben.

## Entwicklung

Quellcode, Tests und neue Versionen: https://github.com/SkodeX/klarsicht-wow
