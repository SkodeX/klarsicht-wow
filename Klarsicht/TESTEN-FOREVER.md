# Klarsicht in WoW Forever testen

Danke fürs Testen! Das dauert etwa 15 Minuten. Am Ende brauchen wir einen Screenshot vom Chat nach `/ks status` und Screenshots von Fehlermeldungen, falls welche kamen.

## Installation

1. Den Ordner `Klarsicht` nach `World of Warcraft\_classic_beta_\Interface\AddOns\` kopieren (das ist der Ordner der Forever-Beta; nach dem Launch der Forever-Spielordner). Direkt in `AddOns\Klarsicht\` muss die Datei `Klarsicht.toc` liegen.
2. In der Charakterauswahl unter „AddOns“ prüfen, dass Klarsicht aktiv ist. Steht dort „veraltet“: „Veraltete AddOns laden“ anhaken und uns im Spiel die Zahl von `/dump (select(4, GetBuildInfo()))` schicken.
3. Fehlermeldungen sichtbar machen: im Chat `/console scriptErrors 1` eingeben.

## Einrichten

4. `/ks` öffnet das Fenster. Als Magier oder Priester „Klassen-Vorschlag laden“ klicken. Andere Klassen ziehen drei, vier Zauber mit Abklingzeit aus dem Zauberbuch auf das Feld „Zauber hierher ziehen“.

## Testen

Bitte zu jedem Punkt kurz notieren: klappt oder klappt nicht.

| # | Was tun | Was passieren sollte |
|---|---|---|
| 5 | Außerhalb des Kampfes einen Zauber mit Abklingzeit wirken | Spirale läuft, weiße Zahl zählt runter, unter 3 Sekunden rot mit Nachkommastelle |
| 6 | Im Kampf (Trainingspuppe oder Mob) einen Zauber mit Abklingzeit wirken | Spirale läuft. Die Zahl kommt jetzt von Blizzard und sieht anders aus, das ist so gewollt |
| 7 | Kampf beenden, während eine Abklingzeit noch läuft | Spirale läuft weiter, die Klarsicht-Zahl ist wieder da |
| 8 | Gegner weit weg anvisieren, dann näher rangehen, einmal ohne und einmal im Kampf | Weit weg grau, in Reichweite wieder farbig |
| 9 | Mana leer machen | Symbol wird blau |
| 10 | Falls die Klasse Proc-Leuchten von Blizzard hat: auf einen Proc warten | Symbol leuchtet golden |
| 11 | Einen Zauber auswählen, „Solange dieser Buff aktiv ist“ anhaken und den Namen eines eigenen Buffs eintragen; Buff außerhalb und im Kampf aktiv haben | Leuchtet außerhalb des Kampfes. Im Kampf darf es ausfallen, bitte melden, was passiert |
| 12 | Bei einem Zauber „Anzeigen: Nur im Kampf“ wählen, Fenster schließen | Symbol erscheint nur im Kampf |
| 13 | „Blasser während Abklingzeit“ anhaken, im Kampf wirken | Symbol wird blasser, solange die Abklingzeit läuft |
| 14 | `/ks unlock`, Symbole ziehen, mit Alt ziehen, mit Shift ziehen, dann `/ks lock` | Gitter erscheint, Symbol rastet ein; Alt bewegt alle; Shift schiebt frei; nach `lock` ist das Gitter weg |
| 15 | „Profil exportieren“, Text mit Strg+C kopieren; dann „Profil importieren“, einfügen, „Ersetzen“ | Alles ist wieder genau wie vorher. Den Text bitte auch an uns schicken |
| 16 | `/reload` | Alle Einstellungen und Positionen bleiben erhalten |

## Zurückmelden

- Nach einem Kampf `/ks status` eingeben und den Chat abfotografieren (Screenshot).
- Screenshots von Fehlermeldungen, falls welche kamen.
- Welche Punkte haben nicht geklappt?
