# Klarsicht

Schlankes Spell- und Buff-Tracking für World of Warcraft Classic und WoW Forever. Wie WeakAuras, nur für Zauber, Buffs und Debuffs und ohne Einarbeitung: Du wählst, was du sehen willst, Klarsicht zeigt es als Symbole dort, wo du sie haben willst. Den Rest deines UIs lässt es in Ruhe.

- **Abklingzeit** als Spirale und Zahl, auf Wunsch grau oder blasser, solange sie läuft
- **Grau** außer Reichweite, **blau** ohne Mana
- **Leuchten** bei einem Proc (auch Talent-Procs wie Missile Barrage), wenn der Zauber im Kampf bereit ist, oder solange ein Buff aktiv ist
- **Buffs und Debuffs** auf dir oder deinem Ziel: Restzeit, Stapel, Erinnerung, wenn etwas fehlt; Auswahl per Klick aus dem, was gerade aktiv ist
- **Sichtbarkeit** pro Symbol: immer, nur im Kampf, nur mit feindlichem Ziel; Live-Vorschau, solange die Einstellungen offen sind
- **Verschieben und Größe** per Maus, mit Gitter, Magnet und Andocken an andere Symbole
- **Rückgängig** (3 Schritte) und **Zurücksetzen** pro Symbol oder für alle Positionen
- **Zahlen-Stil**: Farbe, Rand und Größe
- **Profile** als Textzeile exportieren und importieren, z. B. für Freunde oder Twinks
- **Klassen-Vorschläge** für Magier und Priester, Volksfähigkeiten für alle Klassen

## Download und Installation

1. Unter [Releases](https://github.com/SkodeX/klarsicht-wow/releases/latest) die Datei `Klarsicht-x.y.z.zip` herunterladen. Bitte nicht „Code → Download ZIP“ nehmen, dort hat der Ordner einen Namen, den das Spiel nicht erkennt.
2. Entpacken und den Ordner `Klarsicht` in den AddOns-Ordner der Spielversion kopieren:
   - Classic Era und Hardcore: `World of Warcraft\_classic_era_\Interface\AddOns\`
   - Forever-Beta: `World of Warcraft\_classic_beta_\Interface\AddOns\`
3. Im Spiel `/ks` eingeben.

| Client | Version | Interface | Stand |
|---|---|---|---|
| Classic Era und Hardcore | 1.15.9 | 11509 | mit nachgebauter WoW-API getestet, Spieltest läuft |
| WoW Forever (Beta) | 1.60.1 | 16001 | mit nachgebauter WoW-API getestet, Spieltest läuft ([Testanleitung](Klarsicht/TESTEN-FOREVER.md)) |
| Anniversary | 2.5.6 | 20506 | sollte laufen, ungetestet |
| Mists of Pandaria Classic | 5.5.4 | 50504 | sollte laufen, ungetestet |

## Bedienung

| Befehl | Wirkung |
|---|---|
| `/ks` | Einstellungsfenster öffnen |
| `/ks unlock` / `/ks lock` | Symbole mit Gitter verschieben und vergrößern / fixieren |
| `/ks undo` | letzten Schritt rückgängig machen (bis zu 3) |
| `/ks export` / `/ks import` | Profil als Text kopieren / laden |
| `/ks status` | Version und Diagnose für Fehlerberichte |

Die ausführliche Anleitung mit Beispielen für Magier und Priester steht in [Klarsicht/README.md](Klarsicht/README.md).

Klarsicht nutzt nur Blizzards offizielle Addon-Schnittstelle und zeigt nur an. Es zaubert nicht und automatisiert nichts.

## Projektaufbau

| Ordner | Inhalt |
|---|---|
| `Klarsicht/` | das Addon; genau dieser Ordner kommt ins Spiel |
| `tests/` | Tests: das Addon läuft in einer Lua-VM gegen eine nachgebaute WoW-API, für Classic und Forever, auf Deutsch und Englisch (Szenarien: Magier, Priester, Layout, Buffs/Debuffs) |
| `scripts/package.ps1` | baut `dist/Klarsicht-<Version>.zip` aus dem Addon-Ordner |

## Entwicklung

Tests (Node.js nötig):

```
cd tests
npm install
node run.js
```

Die Tests scheitern auch, wenn das Addon eine Fenster-Methode benutzt, die nicht in allen Clients dokumentiert ist. Die Liste dieser Methoden steht in `tests/methods.lua`. Sie wird mit `tests/methods.js` aus Blizzards API-Dokumentation erzeugt ([Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), je ein Branch pro Client).

Paket bauen (Version kommt aus `Klarsicht/Klarsicht.toc`):

```
powershell -File scripts/package.ps1
```
