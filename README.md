# Guild OS Unbroken (Marktplatz mit Suche & Biete, Pinnwand, Main-/Offspec)

Plugin für **Guild OS**: ein Marktplatz für die Gilde. Unter **Suche** steht alles, was jemand braucht – Handwerksaufträge, Aufrufe fürs Skillen, gesuchte Items und Dienste. Unter **Biete** steht alles, was jemand übrig hat oder anbietet. Dazu eine Pinnwand.

## Marktplatz (Tab „Marktplatz“)

Ein Tab mit zwei Unter-Tabs, oben umschaltbar; die Zahl dahinter zeigt, wie viele Einträge es gibt.

### Suche

Ein Formular für alles, was du brauchst. Das Plugin entscheidet selbst, was daraus wird:

- **Herstellbares Item** (eintippen mit Vorschlagsliste, z. B. „red…“, oder Shift-Klick) → **Handwerksauftrag:** Offen → Übernommen → Geliefert. Ein Handwerker klickt „Übernehmen“, dann „Geliefert“; du bekommst eine Chat-Meldung. Dazu Zurückgeben, Stornieren, Flüstern, „Meine Mats“.
- **Anderes Item** (Kräuter, Erz, Drops …) oder ein **Dienst** (z. B. „Schlossknacken“, „Portal nach Darnassus“) → **Suche:** Die anderen klicken **„Hab ich“**, du bekommst eine Meldung mit Ton und klickst am Ende „Bekommen“ oder „Entfernen“.
- **„Fürs Skillen“ ankreuzen** (oder eine Gruppe wie „Leder“ wählen) → **Aufruf:** *„Hey, wenn du 20x [Leinenstoff] nicht mehr brauchst – schick's mir fürs Skillen!“* Jeder kann etwas schicken und klickt „Geschickt“, so oft er will. Der Aufruf bleibt, bis du ihn beendest oder 30 Tage nichts passiert. Gruppen: Stoff, Leder & Bälge, Erz & Barren, Steine, Kräuter, Verzauberungsmaterial.
- **Wer kann's herstellen?** Im Tooltip die Handwerker der Gilde (und wer online ist) mit ihrer Spezialisierung (z. B. Waffenschmied, Goblin-Ingenieur), soweit Guild OS sie kennt; dazu die **Materialliste** mit deinem Bestand (WoW: Forever).
- **Für mich:** Aufträge, die du herstellen kannst, Aufrufe und Suchen nach Items, die du dabeihast, und Dienste, die du kannst. Diese melden sich immer, mit Ton.
- **Filter:** Alle · Für mich · Items · Dienste · Meine.
- Offene Aufträge verschwinden nach 14 Tagen, Suchen nach einer Woche.

### Biete

- **Items:** Item aus der Tasche auf das Item-Feld (oder aufs Textfeld) ziehen, shift-klicken oder eintippen. Dazu Anzahl, optional ein Preis (freier Text: „5g“, „umsonst“, „gegen Mats“) und eine Notiz.
- **Dienste:** Einfach eintippen, z. B. „Schlossknacken“ oder „Ich verzaubere +5 Ausdauer auf Brust“.
- Die anderen klicken **„Will ich“**, du bekommst eine Meldung mit Ton und siehst im Tooltip, wer es will. Dann anflüstern und per Post oder Handel übergeben; **„Vergeben“** oder **„Entfernen“** nimmt das Angebot heraus. Ein Angebot läuft eine Woche.
- **Filter:** Alle · Items · Dienste · Meine.

### Bekannte Dienste

**Schlossknacken** (Schurken) kennt das Plugin: Es steht in den Vorschlägen (auch bei „Schließkassette“ oder „Lockpicking“), hat ein eigenes Symbol und heißt bei jedem in seiner Sprache. Sucht jemand Schlossknacken, bekommen alle Schurken mit Plugin eine Meldung mit Ton, und der Tooltip zeigt, wer in der Gilde Schurke ist (online zuerst).

### Hinweise

- Chat-Meldung und Popup bei jedem neuen Eintrag eines anderen, je Unter-Tab abschaltbar („Alle melden“/„Melden“, „Popup“). Das Popup ist verschiebbar, schließt sich nach 25 Sekunden und wartet im Kampf.
- **Automatischer Abgleich** mit allen Gildenmitgliedern, die das Plugin nutzen, auch mit denen, die gerade offline waren.
- **Gildenaustritt:** Verlässt ein Charakter die Gilde, verschwinden seine Aufträge und Marktplatz-Einträge (sobald er 5 Minuten nicht mehr im Gilden-Roster steht).
- **Alle Items im Eingabefeld:** Die Liste baut sich nach dem ersten Login einmal langsam im Hintergrund auf (nicht im Kampf, nicht in Instanzen; etwa 10–20 Minuten) und wird gespeichert.
- **Versions-Marker im Guild-OS-Roster:** ein zweiter Punkt für dieses Plugin – lila = aktuell, rot = veraltet.
- Deutsch und Englisch.

## My Char (Tab „My Char“)

Jeder Charakter trägt ein, welchen Talentbaum seiner Klasse er spielt (**Mainspec**) und welchen er bei Bedarf übernimmt (**Offspec**, optional). Beim Druiden ist Wilder Kampf als Tank und als Schaden getrennt.

- **Eintragen:** im eigenen Tab **„My Char“** (oder `/gspec`, `/mychar`). Darunter steht, was die Gilde von dir sieht. Ein Klick speichert sofort; ein Hinweis im Chat erinnert jeden Charakter einmal daran.
- **Anzeigen:** Im Roster von Guild OS steht im Tooltip jedes Mitglieds seine Main- und Offspec mit Rollen-Symbol und Rolle (Tank, Heiler, Schaden).
- Wird automatisch mit allen Gildenmitgliedern abgeglichen, die das Plugin haben.

## Keys (Tab „Keys“)

Eine Tabelle: wer in der Gilde welchen Endgame-Schlüssel und welche Einstimmung hat. Erkannt werden:

- **Schlüssel:** Schattenschmiedeschlüssel (BRD), Schlüssel zur Stadt (Strat), Skelettschlüssel (Scholo), Mondsichelschlüssel (DM), Siegel des Aufstiegs (UBRS), Drachenfeueramulett (Ony)
- **Einstimmungen:** Geschmolzener Kern (MC), Pechschwingenhort (BWL), Naxxramas (Naxx)
- **UBRS-Edelsteine:** Wer das Siegel noch nicht hat, sieht in der UBRS-Spalte die drei Edelsteine (Felsspitz von Hochlord Omokk, Glutdorn von Kriegsherr Voone, Blutaxt von Oberanführer Wyrmthalak): vorhandene farbig, fehlende grau. Der Tooltip zeigt, welcher fehlt und wer ihn droppt.

- Nichts eintragen: Das Plugin schaut selbst in Taschen, Schlüsselbund und Bank (die Bank zählt, sobald du sie einmal geöffnet hast) und in die abgeschlossenen Einstimmungs-Quests. Einmal gefunden, bleibt ein Schlüssel eingetragen.
- Über jedem Schlüssel steht, wie viele ihn haben; der Tooltip zeigt den Gegenstand und alle Namen. „Nur online“ blendet Offline-Mitglieder aus.
- Wird automatisch mit allen Gildenmitgliedern abgeglichen, die das Plugin haben. `/gkeys` öffnet den Tab.

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

- `/gco` oder `/craftorders` öffnet den Marktplatz bei „Suche“, `/gmarkt` bei „Biete“; alternativ `/gos open craftorders` oder direkt im Guild-OS-Fenster.
- `/gboard` oder `/pinnwand` öffnet die Pinnwand, alternativ `/gos open board`.
- `/gspec` oder `/mychar` öffnet den Tab „My Char“, alternativ `/gos open mychar`.
- `/gkeys` öffnet den Tab „Keys“, alternativ `/gos open keys`.
- Ein- und ausschalten lässt sich das Plugin in den **Guild-OS-Einstellungen**.
- Einträge sehen nur Gildenmitglieder, die das Plugin ebenfalls installiert haben.

## Hinweis

Das Plugin ist unabhängig von **GuildHub**: Beide Addons haben eigene Aufträge und teilen sie nicht miteinander.
