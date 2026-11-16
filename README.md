# Guild OS Unbroken (Handwerksaufträge, Marktplatz, Pinnwand)

Plugin für **Guild OS**: Handwerksaufträge innerhalb der Gilde. Du fragst einen Gegenstand an, ein Handwerker übernimmt den Auftrag und liefert ihn. Oder du rufst die Gilde auf, dir übrige Sachen fürs Skillen zu schicken.

## Funktionen

- **Eigener Tab „Aufträge“** im Guild-OS-Fenster
- **Auftrag anlegen:** Gegenstand eintippen (mit Vorschlagsliste, z. B. „red…“) oder per Shift-Klick einfügen, Menge, Notiz, „Meine Mats“
- **Ablauf:** Offen → Übernommen → Geliefert. Sobald der Handwerker auf „Geliefert“ klickt, ist der Auftrag erledigt und verschwindet aus der Liste; der Auftraggeber bekommt eine Chat-Meldung. Dazu Zurückgeben, Stornieren, Flüstern
- **„Fürs Skillen“ (Übrig? Schick's mir fürs Skillen):** Statt eines Handwerksauftrags sieht die Gilde: *„Hey, wenn du 20x [Leinenstoff] nicht mehr brauchst – schick's mir fürs Skillen!“* Jeder, der etwas übrig hat, schickt es dir per Post und klickt auf „Geschickt“, so oft er will. Du bekommst jedes Mal eine Chat-Meldung. Wer das Item in der Tasche hat, wird benachrichtigt und findet den Aufruf unter „Für mich“. Der Aufruf bleibt, bis du ihn beendest oder 30 Tage nichts passiert.
- **Wer kann's herstellen?** Zeigt die Handwerker der Gilde (und wer online ist) aus den Rezeptdaten von Guild OS, mit ihrer Spezialisierung (z. B. Waffenschmied, Goblin-Ingenieur), soweit Guild OS sie kennt
- **Ganze Gruppen fürs Skillen:** Stoff, Leder & Bälge, Erz & Barren, Steine, Kräuter, Verzauberungsmaterial. Einfach z. B. „Leder“ tippen oder „Fürs Skillen“ ankreuzen, dann stehen alle Gruppen zur Auswahl. Andere sehen, wie viel sie aus der Gruppe in den Taschen haben
- **Filter:** Alle · Für mich · Meine
- **Materialliste** im Tooltip mit deinem Bestand (WoW: Forever)
- **Chat-Hinweise** bei jedem neuen Auftrag (abschaltbar mit „Alle melden“), mit Ton, wenn du ihn herstellen kannst oder Items dafür hast, und wenn dein Auftrag übernommen bzw. geliefert wurde
- **Popup bei jedem neuen Auftrag** eines anderen: ein kleines, verschiebbares Fenster mit „Anzeigen“; schließt sich nach 25 Sekunden von selbst, im Kampf wartet es bis danach. Abschalten mit „Keine Popups mehr“ im Popup oder dem Häkchen „Popup“ im Tab
- **Alle Items im Eingabefeld:** nicht nur Herstellbares, auch Kräuter, Erze, Barren, Drops. Die Liste baut sich nach dem ersten Login einmal langsam im Hintergrund auf (nicht im Kampf, nicht in Instanzen; etwa 10–20 Minuten) und wird gespeichert
- **Automatischer Abgleich** mit allen Gildenmitgliedern, die das Plugin nutzen, auch mit denen, die gerade offline waren
- **Update-Hinweis:** Nach dem Login meldet ein Popup, wenn ein Gildenmitglied schon eine neuere Version des Plugins nutzt (einmal pro Version und Sitzung). Abschalten im Popup, wieder einschalten mit `/gco version`
- **Versions-Marker im Guild-OS-Roster:** neben dem Punkt von Guild OS ein zweiter Punkt für dieses Plugin – lila = aktuell, rot = veraltet; die Version steht im Tooltip der Zeile
- Offene Aufträge verschwinden nach 14 Tagen von selbst (Skill-Aufrufe siehe oben)
- Deutsch und Englisch

## Marktplatz (Tab „Marktplatz“)

Biete und Suche für Items und Dienste, die ganze Gilde sieht es:

- **Biete oder Suche:** Der Knopf ganz links schaltet um. **Biete** = du hast etwas für die Gilde, **Suche** = du brauchst etwas von der Gilde.
- **Items:** Item aus der Tasche auf das Item-Feld (oder aufs Textfeld) ziehen, shift-klicken oder eintippen (mit Vorschlägen). Dazu Anzahl, optional ein Preis (freier Text: „5g“, „umsonst“, „gegen Mats“) und eine Notiz.
- **Dienste:** Einfach eintippen, z. B. „Ich öffne Schließkassetten“ oder „Suche Portal nach Darnassus“. Alles, was kein Item ist, gilt als Dienst.
- **Antworten:** Auf ein Angebot klicken die anderen **„Will ich“**, auf eine Suche **„Hab ich“**. Du bekommst eine Meldung mit Ton und siehst im Tooltip, wer es will oder hat. Dann einfach anflüstern und per Post oder Handel übergeben.
- **Du hast es dabei?** Sucht jemand ein Item, das du in Taschen oder Bank hast, steht das in der Zeile, und die Meldung kommt immer, mit Ton.
- **Filter:** Alle · Biete · Suche · Items · Dienste · Meine.
- **„Vergeben“** (bei einer Suche **„Bekommen“**) oder **„Entfernen“** nimmt den Eintrag heraus. Ein Eintrag läuft eine Woche.
- Chat-Meldung und Popup (mit „Will ich“ bzw. „Hab ich“) bei jedem neuen Eintrag, beides abschaltbar („Melden“, „Popup“). `/gmarkt` öffnet den Tab.

## Pinnwand (Tab „Pinnwand“)

Ein Schwarzes Brett für die Gilde:

- **Posten:** Oben eine Nachricht eintippen (bis 300 Zeichen) und „Posten“ klicken oder Enter drücken. Die ganze Gilde (mit Plugin) sieht sie, auch wer gerade offline war.
- **Antworten:** „Antworten“ unter einem Beitrag klappt den Verlauf mit allen Antworten und einem Eingabefeld auf. Eigene Antworten lassen sich mit „x“ entfernen, eigene Beiträge mit „Entfernen“.
- **Hinweise:** Chat-Meldung und Popup bei jedem neuen Beitrag (abschaltbar mit „Melden“ und „Popup“). Antworten auf deine Beiträge kommen immer, mit Ton; Antworten in einem Verlauf, in dem du mitgeschrieben hast, als Chatzeile.
- **Filter:** Alle · Meine (eigene Beiträge und die, auf die du geantwortet hast). Sortiert nach der letzten Aktivität.
- Ein Beitrag bleibt zwei Wochen nach dem letzten Wort im Verlauf. `/gboard` oder `/pinnwand` öffnet den Tab.

## Installation

1. **Guild OS** muss installiert sein (z. B. über CurseForge oder Wago). Ohne Guild OS lädt das Plugin nicht.
2. Das Spiel schließen oder ausloggen.
3. Die Zip-Datei entpacken und den Ordner **`GuildOS_Unbroken`** in den AddOns-Ordner kopieren:
   - WoW: Forever: `World of Warcraft\_forever_\Interface\AddOns\`
   - Retail: `World of Warcraft\_retail_\Interface\AddOns\`

   Danach muss es so aussehen: `...\Interface\AddOns\GuildOS_Unbroken\GuildOS_Unbroken.toc`
   (nicht doppelt verschachtelt wie `GuildOS_Unbroken\GuildOS_Unbroken\...`)

   **Umstieg vom alten „GuildOS_CraftOrders“:** Das Plugin hieß früher so. Den alten Ordner `GuildOS_CraftOrders` löschen, sonst laufen beide (das neue schaltet das alte beim Login aus und meldet sich). Gespeichertes kommt mit, wenn du im Ordner `WTF\Account\<KONTO>\SavedVariables\` die Datei `GuildOS_CraftOrders.lua` zu `GuildOS_Unbroken.lua` kopierst; sonst holt sich das Plugin die Aufträge, Angebote und Beiträge einfach wieder von der Gilde.
4. Spiel starten und in der Addon-Liste prüfen, dass **Guild OS Unbroken** aktiviert ist.

## Benutzung

- `/gco` oder `/craftorders` öffnet den Tab, alternativ `/gos open craftorders` oder direkt im Guild-OS-Fenster.
- `/gmarkt` öffnet den Marktplatz, alternativ `/gos open market`.
- `/gboard` oder `/pinnwand` öffnet die Pinnwand, alternativ `/gos open board`.
- Ein- und ausschalten lässt sich das Plugin in den **Guild-OS-Einstellungen**.
- Aufträge sehen nur Gildenmitglieder, die das Plugin ebenfalls installiert haben.

## Hinweis

Das Plugin ist unabhängig von **GuildHub**: Beide Addons haben eigene Aufträge und teilen sie nicht miteinander.
