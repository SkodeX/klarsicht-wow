# Klarsicht

Schlankes Spell- und Buff-Tracking für WoW Classic und WoW Forever. Klarsicht ersetzt kein UI, sondern legt nur die Symbole auf den Bildschirm, die du sehen willst.

**Zauber**
- **Abklingzeit** als Spirale und Zahl (unter 3 Sekunden mit Nachkommastelle, rot); auf Wunsch grau oder blasser, solange sie läuft
- **Grau**, wenn das Ziel außer Reichweite ist; **blau**, wenn Mana fehlt; dunkel, wenn der Zauber gerade nicht nutzbar ist
- **Leuchten** bei einem Proc (auch Talent- und Runen-Procs wie Missile Barrage, Freizaubern oder Hot Streak, die den Zauber kostenlos oder sofort machen), wenn der Zauber im Kampf bereit ist, oder solange ein bestimmter Buff aktiv ist

**Buffs und Debuffs**
- auf dir oder auf deinem Ziel, auf Wunsch nur deine eigenen
- Restzeit als Spirale und Zahl, Stapel unten rechts
- anzeigen nur, wenn aktiv, nur, wenn es fehlt (Erinnerung), oder immer (grau, wenn es fehlt)
- leuchten, wenn es fehlt (im Kampf), oder kurz bevor es ausläuft

**Für alle Symbole**
- Sichtbarkeit: immer, nur im Kampf, nur mit feindlichem Ziel
- Größe und Position frei, per Maus mit Gitter, Magnet und Andocken an andere Symbole
- Rückgängig für die letzten 3 Schritte, Zurücksetzen pro Symbol und für alle Positionen
- Farbe, Rand und Größe der Zahlen einstellbar
- Profile als Textzeile exportieren und importieren

Die Einstellungen werden pro Charakter gespeichert (`KlarsichtCharDB`).

## Installation

Den Ordner `Klarsicht` nach `…\World of Warcraft\_classic_era_\Interface\AddOns\` kopieren (für Forever in den Forever-Spielordner). Danach im Charakter-Auswahlbildschirm unter „AddOns“ prüfen, dass Klarsicht aktiv ist.

Die TOC-Datei deckt Classic Era 1.15.9 (11509), Anniversary 2.5.6 (20506), Mists 5.5.4 (50504) und Forever 1.60.1 (16001) ab. Steht Klarsicht nach einem Patch als „veraltet“ in der Liste, im Spiel `/dump (select(4, GetBuildInfo()))` eingeben und die Zahl in `Klarsicht.toc` bei `## Interface:` ergänzen.

## Bedienung

| Befehl | Wirkung |
|---|---|
| `/ks` oder `/klarsicht` | Einstellungsfenster öffnen/schließen |
| `/ks unlock` | Symbole mit der Maus verschieben und vergrößern, Gitter einblenden |
| `/ks lock` | Symbole fixieren, Gitter ausblenden, Klicks gehen wieder durch |
| `/ks undo` | letzten Schritt rückgängig machen (bis zu 3) |
| `/ks export` | Profil als Text zum Kopieren anzeigen |
| `/ks import` | Profil aus kopiertem Text laden |
| `/ks status` | Version, Client und Zähler für die Forever-Sonderwege im Chat ausgeben (für Testberichte) |

Das Fenster ist außerdem unter Optionen → AddOns → Klarsicht erreichbar. Links stehen deine Einträge, rechts gibt es zwei Reiter: **Zauber** (Einstellungen des gewählten Eintrags) und **Allgemein** (Gitter, Magnet, Zahlen-Stil, Positionen zurücksetzen).

**Hinzufügen**
- Namen oder Spell-ID eintippen und Enter drücken, oder einen Zauber aus dem Zauberbuch auf das Feld „Zauber hierher ziehen“ ziehen. Bei Classic-Zaubern mit Rängen folgt Klarsicht automatisch dem höchsten gelernten Rang.
- **Buff/Debuff** öffnet eine Liste mit allem, was gerade auf dir und deinem Ziel liegt. Ein Klick verfolgt den Eintrag.
- Ein eingetippter Name, der nicht im Zauberbuch steht, wird als Buff auf dir angelegt. Unter „Verfolgen“ lässt sich das ändern. Das Symbol lernt Klarsicht, sobald der Buff einmal zu sehen war.
- Unter „Verfolgen“ wird aus jedem Eintrag ein Zauber, ein Buff oder Debuff auf dir oder auf dem Ziel. Derselbe Zauber darf zweimal in der Liste stehen, z. B. Eisbarriere einmal für die Abklingzeit und einmal als Buff mit Restzeit.

**Klassen-Vorschlag** fügt die wichtigen Abklingzeiten hinzu, die der Charakter kennt, als Reihe unter dem Charakter. Mehrfach klicken schadet nicht: Neu gelernte Zauber kommen dazu, vorhandene bleiben.

- **Magier:** Gegenzauber, Frostnova, Blinzeln, Feuerschlag, Kältekegel, Hervorrufung und Talente wie Geistesgegenwart, Arkane Macht, Verbrennung, Eisblock, Kälteeinbruch, Eisbarriere
- **Priester:** Machtwort: Schild, Gedankenschlag, Psychischer Schrei, Verblassen, die Volks-Priesterzauber (z. B. Verzweifeltes Gebet, Furchtzauberschutz, Elunes Anmut, Sternensplitter, Verschlingende Seuche) und Talente wie Heiliges Feuer, Innerer Fokus, Seele der Macht, Stille, Brunnen des Lichts
- **Alle Klassen:** die Volksfähigkeit mit Abklingzeit, z. B. Wille der Verlassenen, Steingestalt, Schattenhaftigkeit, Wachsamkeit, Berserker

**Live-Vorschau:** Solange das Fenster offen ist, wirkt jede Änderung sofort. Symbole, die deine Sichtbarkeitsregel gerade ausblendet, bleiben blass sichtbar, und unter den Einstellungen steht, warum (z. B. „Gerade ausgeblendet: nicht im Kampf“). Das gewählte Symbol ist blau hinterlegt.

### Verschieben, Größe, Gitter

„Symbole verschieben“ (oder `/ks unlock`) blendet ein Gitter über den Bildschirm. Die goldenen Linien laufen durch die Bildschirmmitte.

- **Ziehen** verschiebt ein Symbol, unter ihm stehen die Koordinaten.
- **Die Ecke unten rechts ziehen** ändert die Größe (16 bis 96 px), die obere linke Ecke bleibt stehen.
- **Alt** beim Anklicken: alle Symbole wandern zusammen, die Abstände bleiben gleich.
- **Shift** während des Ziehens: frei schieben, ohne Einrasten oder Andocken.

Im Reiter **Allgemein**:
- **Raster** 4, 8, 16, 32 oder 64 px, Gitter anzeigen und Am Gitter einrasten an/aus.
- **Magnet**: Wie nah ein Symbol an eine Gitterlinie kommen muss, bevor es einrastet. Klein heißt fein schieben, nur dicht an der Linie rastet es ein. Groß (halbe Rastergröße) heißt, es rastet immer ein.
- **An Symbolen andocken**: Kommt ein Symbol in Magnet-Reichweite einer Stelle direkt neben einem anderen Symbol (rechts, links, oben, unten), sitzt es dort exakt im eingestellten **Abstand**. Andocken hat Vorrang vor dem Gitter.
- **Alle Positionen zurücksetzen** stellt alle Symbole als Reihe unter den Charakter, im eingestellten Abstand.

### Rückgängig und Zurücksetzen

- **Rückgängig** (Knopf unten oder `/ks undo`) nimmt bis zu 3 Schritte zurück: Verschieben, Größe, Einstellungen, Hinzufügen, Entfernen, Klassen-Vorschlag, Import und Zurücksetzen. Ein Schieberegler-Zug oder eine getippte Zahl zählt als ein Schritt. Gitter- und Zahlen-Einstellungen gehören nicht dazu; nach `/reload` ist der Verlauf leer.
- **Zurücksetzen** im Reiter Zauber stellt alle Optionen des gewählten Eintrags auf Standard. Platz und Art (Zauber oder Buff) bleiben.

### Abklingzeit-Zahl

Im Reiter Allgemein für alle Symbole gemeinsam: **Farbe** (8 Farben), **Rand** (ohne, dünn, dick) und **Größe** (50 bis 200 %). Unter 3 Sekunden wird die Zahl immer rot. Blizzards eigene Zahl, die in Forever im Kampf erscheint, bekommt denselben Stil.

### Profile teilen

„Exportieren“ zeigt die ganze Liste als eine Textzeile wie `KS1:id=2139,glowReady=1,x=-88,y=-180;id=122,...:3f2a`. Mit Strg+C kopieren und irgendwo einfügen: Discord, Textdatei oder bei einem anderen Charakter über „Importieren“ (Strg+V).

- **Ersetzen** löscht die aktuelle Liste und übernimmt das Profil; **Ergänzen** fügt nur fehlende Einträge hinzu. Beides lässt sich rückgängig machen.
- Zauber werden über ihre ID übertragen, ein Profil aus einem englischen Client funktioniert also auch im deutschen. Zauber, die der Client nicht kennt, werden übersprungen. Buffs und Debuffs reisen zusätzlich mit ihrem Namen.
- Der Text enthält eine Prüfsumme. Ist er beim Kopieren abgeschnitten oder verändert worden, lehnt Klarsicht ihn ab, statt etwas Halbes zu laden. Beim Import wird nur Text gelesen, nie Code ausgeführt.

### Beispiele für Magier

- **Missile Barrage und Freizaubern:** Arkane Geschosse hinzufügen, „Bei Proc“ bleibt an. Das Symbol leuchtet, sobald die Geschosse nichts kosten.
- **Gegenzauber nie verpassen:** „Wenn bereit (im Kampf)“ anhaken und unter „Anzeigen“ „Nur mit feindlichem Ziel“ wählen.
- **Eisbarriere:** einmal als Zauber (Abklingzeit) und einmal über „Buff/Debuff“ als Buff mit Restzeit.
- **Große Abklingzeiten ohne Unruhe:** Arkane Macht oder Verbrennung auf „Nur wenn bereit“ stellen. Das Symbol taucht nur auf, wenn du es zünden kannst.

### Beispiele für Priester (gut für Hardcore)

- **Notknöpfe im Blick:** Psychischer Schrei, Verblassen und Verzweifeltes Gebet auf „Nur im Kampf“ stellen und „Wenn bereit (im Kampf)“ anhaken.
- **Schattenwort: Schmerz:** als „Debuff auf Ziel“ (nur eigene) mit „Kurz vor Ablauf“ leuchten lassen, dann weißt du, wann du nachlegen musst.
- **Inneres Feuer nie vergessen:** als „Buff auf mir“ mit „Nur wenn es fehlt“ und „Wenn es fehlt (im Kampf)“. Die Stapel stehen unten rechts.
- **Geschwächte Seele:** als „Debuff auf mir“, dann siehst du, wann das nächste Machtwort: Schild auf dich geht.

## WoW Forever

Forever läuft auf dem modernen Midnight-Client. Dort sind im Kampf manche Werte für Addons „geheim“. Klarsicht geht damit so um:

| Funktion | Im Kampf auf Forever |
|---|---|
| Abklingzeit-Spirale | funktioniert (über Blizzards Duration-Objekt) |
| Abklingzeit-Zahl | Blizzards eigene Countdown-Zahl im Klarsicht-Stil statt der von Klarsicht |
| Reichweite, Mana, Proc-Leuchten (auch Talent-Procs) | funktionieren |
| „Grau/Blasser während Abklingzeit“, „Nur wenn bereit“ | funktionieren (Blizzard gibt „aktiv ja/nein“ frei). Sperrt Blizzard auch das, behalten die Symbole ihren letzten Stand; `/ks status` meldet es. |
| Buffs und Debuffs | nur die, die Blizzard im Kampf freigibt. Die anderen behalten ihren Stand vom Kampfbeginn und aktualisieren sich nach dem Kampf. Auch „Leuchten, wenn es fehlt“ greift dann erst nach dem Kampf. |
| Leuchten bei Buff (Zauber-Option) | kann im Kampf ausfallen, wenn Blizzard den Buff sperrt |

Getestet ist das bisher nur gegen Blizzards API-Dokumentation und einen nachgebauten Client, nicht im echten Spiel. Die Anleitung für einen Test in Forever steht in [TESTEN-FOREVER.md](TESTEN-FOREVER.md); `/ks status` zeigt danach, ob die Forever-Sonderwege gegriffen haben.

## Entwicklung

Quellcode, Tests und neue Versionen: https://github.com/SkodeX/klarsicht-wow
