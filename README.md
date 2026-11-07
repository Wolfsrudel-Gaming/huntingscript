# wr_hunting – Realistisches Jagdsystem für FiveM (ESX)

Jagen direkt in der normalen Spielwelt, ohne Instanzen, ohne Jagd-„Sessions“ und ohne Job.
Wildtiere leben in festgelegten Jagdrevieren, reagieren auf Spieler und Schüsse, und alles
danach (Ausnehmen, Gerben, Grillen, Essen, Verkaufen, Trophäen) passiert ebenfalls in der offenen Welt.

## Features

| Bereich | Beschreibung |
|---|---|
| **Jagdreviere** | Tiere spawnen nur in konfigurierten Gebieten der normalen Map (Paleto Forest, Chiliad Wilderness, Mount Chiliad, Grand Senora). Map-Blips und Hinweise beim Betreten/Verlassen. |
| **Natürliches Spawning** | Der Server erstellt die Tiere als vernetzte Peds (OneSync), nur wenn Spieler im Revier sind, außer Sichtweite, auf geeignetem Boden (kein Wasser, keine Steilhänge, keine Interiors). Tierart abhängig von Tageszeit (z. B. Kojoten nachts). Gruppen/Rudel. Automatisches Entfernen ohne Spieler in der Nähe. |
| **Tier-KI** | Fluchttiere (Hirsch, Kaninchen) nehmen Spieler je nach Haltung wahr (Schleichen, Sprinten, Fahrzeug, Sichtlinie, Nacht) und flüchten. Schüsse in der Nähe verscheuchen Tiere (Schalldämpfer = kleinerer Radius). |
| **Angriffe** | **Wildschweine und Kojoten greifen Spieler an** und verursachen Schaden (konfigurierbar, inkl. Umrennen beim Wildschwein). Angriff bei Annäherung oder als Gegenangriff nach einem Treffer, nachts aggressiver. |
| **Polizeimeldungen** | Jedes erlegte Tier kann eine Meldung auslösen (Chance je Tierart, + nachts, 100 % außerhalb der Reviere / geschützte Arten / ohne Jagdschein). **Ziehen einer Jagdwaffe außerhalb der Reviere** löst ebenfalls eine Meldung aus (auch beim Verlassen des Reviers mit gezogener Waffe). Ungefähre Position, Straßenname, Geschlecht der Person. |
| **Ausnehmen** | Erlegte Tiere mit einem Messer ausnehmen → **Fleisch und Fell**. Qualität abhängig von Waffe & Treffer (Kopf-/Halsschuss mit Büchse = perfekt, Schrot = beschädigt, Fahrzeug/Explosion = unbrauchbar). |
| **Tierköpfe** | Beim Ausnehmen mit einer Chance von **1 zu 250** ein Tierkopf als Trophäe. Trophäen können als **Deko** an Wände/auf den Boden gesetzt werden (persistent, auch in Instanzen/Wohnungen korrekt nur im eigenen Routing-Bucket sichtbar). |
| **Gerben** | Rohe Felle in einen **Gerbrahmen** spannen; nach Ablauf der Echtzeit (läuft auch offline/bei Neustart weiter) als gegerbtes Fell abholen. |
| **Grillen** | Fleisch auf **jedem Grill der Spielwelt** (`prop_bbq_*` u. a.), an festen Feuerstellen oder an einem selbst gebauten **Lagerfeuer** grillen. |
| **Essen** | Gegrilltes Fleisch essen (Hunger über esx_status + etwas Heilung). Rohes Fleisch ist essbar – mit Risiko, dass einem schlecht wird. |
| **Händler & Ausrüstung** | Händler-NPCs (Wildhändler, Schlachthof) kaufen Beute an. Der Wildhändler verkauft Ausrüstung (Köder, Tarnzelt, Fernglas, Lagerfeuer-Set) und stellt Jagdscheine aus. |
| **Jagdschein** | Eingebauter Jagdschein (Echtzeit-Tage gültig, beim Wildhändler kaufbar/verlängerbar) oder Anbindung an `esx_license`. `/jagdschein` zeigt ihn der nächsten Person, die Polizei prüft mit `/jagdscheinpruefen`. Ohne Schein ist jeder Abschuss Wilderei. |
| **Schonzeiten & Kontingent** | Pro Tierart gesperrte Monate (reales Serverdatum) und ein Tageskontingent pro Spieler. Verstöße werden gemeldet, der Jäger wird gewarnt. `/jagdzeiten` zeigt den aktuellen Stand. |
| **Wind & Witterung** | Serverweit synchronisierter, langsam drehender Wind. Trägt der Wind die Witterung des Jägers zum Tier, bemerkt es ihn viel früher; „unter Wind“ kommt man näher heran. Windanzeige in den Revieren. |
| **Schweißfährte & Nachsuche** | Angeschossene Tiere bluten, hinterlassen eine für alle sichtbare Blutspur (Anschuss mit Blutlache), legen sich schwer verletzt ins Wundbett und verenden schließlich. Der Abschuss wird dem Schützen zugeordnet – finden muss er das Tier selbst. |
| **Köder** | Kirrmais (lockt Wildschweine) und Salzleckstein (lockt Hirsche) im Revier auslegen; nach einiger Zeit zieht Wild aus der Umgebung heran. |
| **Ansitz / Tarnzelt** | Tarnzelt aufstellen – wer darin sitzt, wird von Tieren kaum bemerkt. Optional feste Hochsitze per Config. |
| **Fernglas** | Wild ansprechen: Art, Entfernung, Zustand (ruhig, flüchtig, verwundet …), Jagd-/Schonzeit und Windrichtung. |
| **Jäger-Erfahrung** | Erfahrung für legale Abschüsse, saubere Schüsse, Nachsuchen, Ausnehmen, Gerben und Grillen. Höhere Stufen nehmen schneller aus, bekommen öfter mehr Fleisch und werden später bemerkt. `/jagdstatistik` zeigt Stufe und Statistik. |
| **Polizei-Untersuchung** | Polizisten können Kadaver untersuchen (Taste `G`): Tierart, Todeszeitpunkt, Todesursache, Zustand und Verstöße (Schonzeit, außerhalb des Reviers, Kontingent). |

## Voraussetzungen

- **OneSync** (Legacy oder Infinity) – die Tiere werden serverseitig erstellt
- [es_extended](https://github.com/esx-framework/esx_core) (ESX Legacy)
- [oxmysql](https://github.com/overextended/oxmysql)
- Menü: `esx_context` **oder** `esx_menu_default` (beide Teil von ESX Legacy)
- Optional: `esx_status`/`esx_basicneeds` (Hunger), `esx_license` (Jagdschein), `ox_inventory`

Funktioniert mit `sv_entityLockdown strict`, da alle Tiere serverseitig erstellt werden.

## Installation

1. Ordner nach `resources/[jobs]/wr_hunting` kopieren (Ordnername = Ressourcenname).
2. **Items anlegen**
   - ESX-Standardinventar: `sql/install.sql` importieren.
   - ox_inventory: Einträge aus `install/ox_inventory_items.lua` in `ox_inventory/data/items.lua` einfügen.
3. In der `server.cfg` **nach** `es_extended`, `oxmysql` (und ggf. `ox_inventory`) starten:
   ```cfg
   ensure wr_hunting
   ```
4. Die Tabellen `hunting_trophies`, `hunting_tanning` und `hunting_players` werden beim ersten Start automatisch erstellt.
5. Koordinaten in `config.lua` (Reviere, Gerbrahmen, Feuerstelle, Händler) an euren Server anpassen –
   besonders, wenn ihr eigene MLOs oder Map-Änderungen nutzt.

## Items

| Item | Beschreibung | Benutzbar |
|---|---|---|
| `meat_deer`, `meat_boar`, `meat_coyote`, `meat_rabbit` | Rohes Fleisch | roh essen (Risiko) |
| `cooked_deer`, `cooked_boar`, `cooked_coyote`, `cooked_rabbit` | Gegrilltes Fleisch | essen |
| `pelt_deer`, `pelt_boar`, `pelt_coyote`, `pelt_rabbit` | Rohes Fell | – (Gerbrahmen) |
| `leather_deer`, `leather_boar`, `leather_coyote`, `leather_rabbit` | Gegerbtes Fell | – (Verkauf/Crafting) |
| `trophy_deer`, `trophy_boar`, `trophy_coyote` | Tierkopf-Trophäe (1 : 250) | als Deko platzieren |
| `campfire_kit` | Lagerfeuer-Set | Lagerfeuer bauen |
| `bait_corn` | Kirrmais – lockt Wildschweine | im Revier auslegen |
| `bait_saltlick` | Salzleckstein – lockt Hirsche | im Revier auslegen |
| `hunting_blind` | Tarnzelt (Ansitz) | aufstellen |
| `binoculars` | Fernglas | benutzen |

Zum Ausnehmen wird ein Messer benötigt (`WEAPON_KNIFE`, `WEAPON_SWITCHBLADE`, `WEAPON_DAGGER`,
`WEAPON_MACHETE` – erweiterbar über `Config.Butchering.knifeWeapons` / `knifeItems`).
Die Ausrüstung gibt es beim Wildhändler (`Config.Traders[x].shop`).

## Steuerung

| Aktion | Taste |
|---|---|
| Interagieren (Ausnehmen, Gerbrahmen, Grill, Händler, Trophäe abnehmen, Tarnzelt abbauen) | `E` |
| Kadaver untersuchen (nur Polizei) | `G` |
| Fortschritt abbrechen | `X` |
| Trophäe platzieren | `E` bestätigen, `Backspace`/Rechtsklick abbrechen, Mausrad/Pfeil ←→ drehen, Pfeil ↑↓ Höhe |
| Fernglas | Maus umsehen, Mausrad zoomen, `E`/`Backspace` absetzen |

## Befehle

| Befehl | Recht | Beschreibung |
|---|---|---|
| `/jagdschein` | alle | Eigenen Jagdschein anzeigen und der nächsten Person vorzeigen |
| `/jagdscheinpruefen` | Polizei | Jagdschein der nächsten Person prüfen |
| `/jagdstatistik` | alle | Jäger-Stufe, Erfahrung und Statistik |
| `/jagdzeiten` | alle | Jagd-/Schonzeiten, heutige Abschüsse und Wind |
| `/huntspawn <deer\|boar\|coyote\|rabbit>` | admin | Tier in der Nähe spawnen (Test) |
| `/huntclear` | admin | Alle Jagdtiere entfernen |
| `/trophaeentfernen` | Besitzer/admin | Nächstgelegene Trophäe entfernen (Besitzer bekommt das Item zurück) |

## Konfiguration (Auszug)

Alles befindet sich in `config.lua` und ist kommentiert.

- **`Config.Zones`** – Reviere mit Mittelpunkt, Radius, maximaler Tieranzahl und Gewichtung der Tierarten.
- **`Config.Animals`** – Tierarten: Modell, Lebenspunkte, Verhalten (`prey`/`aggressive`), Wahrnehmung,
  Tageszeit-Aktivität, Polizei-Chance, Beute, Angriffswerte (Reichweite, Schaden, Abklingzeit, Umrennen …).
- **`Config.HuntingWeapons`** – Welche Waffen als Jagdwaffen gelten (Meldung außerhalb der Reviere) und ob
  sie einen sauberen Schuss erlauben.
- **`Config.Police`** – Jobs, Chancen, Abklingzeiten, Blip-Darstellung und Dispatch-Integration.
- **`Config.Butchering.trophyChance`** – Trophäen-Chance (Standard `250` → 1 zu 250).
- **`Config.Tanning`** – Gerbrahmen-Standorte, Dauer je Fell, optionales Gerbmittel.
- **`Config.Cooking` / `Config.Campfire` / `Config.Eating`** – Rezepte, Grill-Modelle, Feuerstellen, Hunger-Werte.
- **`Config.Trophies`** – Modelle der Trophäen, Limit pro Spieler.
- **`Config.Traders`** – Händler, Ankaufspreise, Ausrüstungs-Shop und Jagdschein-Verkauf.
- **`Config.License`** – Jagdschein: eingebaut (Preis, Gültigkeit in Tagen) oder `esx_license`; `enabled = false` schaltet die Pflicht ab.
- **`Config.Seasons`** – Schonzeit-Monate und Tageskontingent je Tierart.
- **`Config.Wind`** – Winddrehung, Witterungs-Multiplikatoren, Anzeige.
- **`Config.Tracking`** – Blutverlust, Blutspur, Wundbett, Zuordnungszeit.
- **`Config.Baits`** – Köder, angelockte Tierarten, Dauer und Verzögerung.
- **`Config.Blinds`** – Tarnzelt, Tarnwirkung, Lebensdauer, feste Hochsitze.
- **`Config.Binoculars`** – Zoom und Reichweite des Fernglases.
- **`Config.Progression`** – Stufen, Erfahrung pro Aktion und Boni.

### Externes Dispatch-System

`Config.Police.dispatch = 'client'` ruft `Config.Police.clientDispatch(alert)` beim Verdächtigen auf.
In der Config sind Beispiele für **cd_dispatch** und **ps-dispatch** auskommentiert enthalten.
Mit `'server'` wird `Config.Police.serverDispatch(source, alert)` serverseitig ausgeführt.

### Trophäen-Modelle (Tierköpfe)

GTA V enthält **keine** Tierkopf-Props. Für echte Wand-Trophäen einen Custom-Prop streamen und den
Modellnamen eintragen:

```lua
trophy_deer = { prop = 'mein_hirschkopf_prop', fallbackPed = 'a_c_deer', wallOffset = 0.05, headingOffset = 0.0 },
```

`headingOffset` korrigiert die Ausrichtung, falls das Modell „falsch herum“ an der Wand hängt.
Ohne (gültiges) Prop wird automatisch ein **Präparat** (das ganze, eingefrorene Tier) aufgestellt,
damit die Trophäen auch ohne Zusatz-Downloads funktionieren.

### Jagdschein

```lua
Config.License = {
    enabled      = true,
    provider     = 'builtin',   -- oder 'esx_license'
    type         = 'hunting',   -- Lizenztyp für esx_license
    price        = 2500,
    durationDays = 7,
    account      = 'bank',
}
```

Mit `builtin` wird der Schein beim Wildhändler gekauft und in `hunting_players` gespeichert.
Wer ohne gültigen Schein jagt, wird bei jedem Abschuss gemeldet (`Config.Police.kill.noLicenseChance`)
und bekommt keine Erfahrung.

## Technische Details

- **Spawning:** Der Server wählt einen Spieler im Revier, dieser Client sucht passende Bodenpunkte
  (die Bodenhöhe ist nur clientseitig bekannt), der Server prüft sie und erstellt die Tiere per `CreatePed`.
- **KI:** Gesteuert vom aktuellen Netzwerk-Besitzer des Tieres. Der Zustand (`wander`/`flee`/`attack` + Ziel)
  liegt in Entity-State-Bags, die nur der Server nach Ownership-Prüfung setzt – bei einem Besitzerwechsel
  übernimmt der neue Client nahtlos.
- **Schaden:** Angriffsschaden wird vom Client des angegriffenen Spielers auf sich selbst angewendet
  (keine Fremdmanipulation von Spieler-Peds nötig).
- **Abschüsse:** Der Server prüft Tod, Entfernung und Todesursache (`GetPedCauseOfDeath`/`GetPedSourceOfDeath`),
  bevor Beute oder Meldungen entstehen. Alle Belohnungen (Ausnehmen, Gerben, Grillen, Verkauf) werden
  serverseitig validiert (Entfernung, Dauer, Sperren, Inventarplatz).
- **Legalität:** Jeder Abschuss wird zentral bewertet (Jagdschein, Schonzeit, Kontingent, Revier, geschützte Art).
  Illegale Abschüsse geben keine Erfahrung, werden in der Statistik gezählt und lösen sicher eine Meldung aus.
- **Nachsuche:** Treffer ohne Todesfolge meldet der Schütze; der Server merkt sich den letzten Treffer. Der
  Besitzer-Client lässt das Tier bluten und schickt Blutpunkte, die der Server an Spieler in der Nähe verteilt.
  Verendet das Tier, wird es dem Schützen mit der Qualität seines Treffers zugeschrieben.
- **Wind, Ansitz, Stufe:** Wind kommt über `GlobalState.huntWind`, Tarnung und Jäger-Stufe über Player-State-Bags
  (`huntHidden`, `huntLevel`) – so kann der Client, der ein Tier steuert, die Wahrnehmung für jeden Spieler berechnen.

## Bekannte Einschränkungen

- Die Standard-Koordinaten sind Richtwerte und sollten im Spiel überprüft werden
  (`/huntspawn` und `Config.Debug = true` helfen beim Testen).
- Wie gut Tiere „von sich aus“ angreifen (Animationen), hängt vom Tiermodell ab. Bleibt ein Tier im
  Kampfmodus stehen, läuft es automatisch aktiv auf das Ziel zu; der Schaden wird unabhängig davon
  über das Skript verteilt.
- Grills der Spielwelt sind dem Server unbekannt; dort wird nur Dauer und Inventar geprüft.
- Köder, Tarnzelte und Lagerfeuer sind nicht persistent und verschwinden bei einem Server-Neustart.
  Ein abgelaufenes Tarnzelt kommt nur zurück ins Inventar, wenn der Besitzer online ist.
- Der Jagdschein ist standardmäßig **Pflicht** (`Config.License.enabled = true`). Ohne gültigen Schein
  wird jeder Abschuss gemeldet.
