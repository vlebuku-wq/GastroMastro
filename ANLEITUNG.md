# Bestand & Bestellung – Web-Version einrichten

Diese Anleitung bringt die App ins Internet, damit du und deine Freunde sie im Browser und auf dem Handy nutzen könnt. Du brauchst keine Programmierkenntnisse. Rechne mit etwa 45 Minuten.

## Was in diesem Ordner liegt

| Datei | Wofür |
|---|---|
| `index.html` | Die App selbst. Kommt auf GitHub. |
| `supabase/schema.sql` | Richtet die Datenbank ein. Wird einmal in Supabase ausgeführt. |
| `supabase/functions/beleg-lesen/index.ts` | Die Belegerkennung für PDFs und Fotos. Kommt zu Supabase. |
| `Bestand-Sicherung_aus-Claude.json` | Deine bisherigen Daten aus der Claude-Version. Wird am Ende eingespielt. |
| `ANLEITUNG.md` | Diese Anleitung. |

## So hängt alles zusammen

- **GitHub** speichert den Code und veröffentlicht die App unter einer Adresse wie `https://deinname.github.io/bestand/`.
- **Supabase** speichert die Daten, verwaltet die Konten und führt die Belegerkennung aus.
- **Anthropic** (die Firma hinter Claude) liest die Belege. Das kostet pro Beleg ein paar Cent.

---

## Schritt 1: Supabase-Projekt anlegen

1. Geh auf [supabase.com](https://supabase.com) und erstelle ein kostenloses Konto (am einfachsten mit GitHub anmelden).
2. Klick auf **New project**.
3. Name: z. B. `bestand`. Denk dir ein Datenbank-Passwort aus und **schreib es dir auf**.
4. Region: **Central EU (Frankfurt)**, damit die Daten in Deutschland liegen.
5. **Create new project**. Das Einrichten dauert ein bis zwei Minuten.

## Schritt 2: Datenbank einrichten

1. Links im Menü: **SQL Editor**.
2. Öffne die Datei `supabase/schema.sql` mit einem Texteditor, markiere alles und kopiere es.
3. Füge es im SQL Editor ein und klick auf **Run**.
4. Unten sollte „Success. No rows returned“ stehen.

Damit sind die Tabellen und die Zugriffsregeln angelegt: Jeder sieht nur die Daten der Lager, in denen er Mitglied ist.

## Schritt 3: Schlüssel in die App eintragen

1. In Supabase: **Project Settings** (Zahnrad) → **API** bzw. **Data API**.
2. Kopiere die **Project URL** (sieht aus wie `https://abcdefgh.supabase.co`).
3. Kopiere den Schlüssel **anon public** (ein langer Text, beginnt meist mit `eyJ`).
4. Öffne `index.html` mit einem Texteditor (z. B. Notepad, TextEdit im Modus „Reiner Text“ oder VS Code).
5. Suche ganz oben im Skript-Teil diese zwei Zeilen und trag die Werte zwischen die Anführungszeichen ein:

   ```js
   const SUPABASE_URL = "https://abcdefgh.supabase.co";
   const SUPABASE_ANON_KEY = "eyJ...";
   ```

6. Speichern.

Der `anon public`-Schlüssel darf öffentlich sein, die Zugriffsregeln aus Schritt 2 schützen die Daten. **Niemals** gehört der `service_role`-Schlüssel oder dein Anthropic-Schlüssel in diese Datei.

## Schritt 4: App auf GitHub veröffentlichen

1. Erstelle ein Konto auf [github.com](https://github.com), falls du noch keins hast.
2. Oben rechts **+** → **New repository**.
   - Name: `bestand`
   - **Public** auswählen (für kostenlose GitHub-Seiten nötig; es steht nichts Geheimes im Code).
   - **Create repository**.
3. Auf der neuen Seite: **uploading an existing file** anklicken.
4. Zieh `index.html` hinein (gern auch `ANLEITUNG.md` und den Ordner `supabase`, aber **nicht** die Sicherungsdatei mit deinen Daten). Unten **Commit changes**.
5. Im Repository: **Settings** → **Pages**.
   - Source: **Deploy from a branch**
   - Branch: **main**, Ordner **/ (root)** → **Save**.
6. Nach ein bis zwei Minuten steht oben die Adresse, z. B. `https://deinname.github.io/bestand/`. Das ist deine App.

## Schritt 5: Supabase die Adresse der App mitteilen

Damit Bestätigungs-Mails und „Passwort vergessen“ zur App zurückführen:

1. Supabase → **Authentication** → **URL Configuration**.
2. **Site URL**: deine App-Adresse aus Schritt 4.
3. Unter **Redirect URLs** dieselbe Adresse noch einmal hinzufügen.
4. Speichern.

## Schritt 6: Belegerkennung einrichten (für PDFs und Fotos)

Ohne diesen Schritt funktioniert alles außer dem Auslesen von PDFs und Fotos. CSV-Import geht auch ohne.

**a) Anthropic-Schlüssel holen**

1. Geh auf [console.anthropic.com](https://console.anthropic.com) und erstelle ein Konto.
2. Unter **Billing** etwas Guthaben aufladen (5 € reichen für sehr viele Belege).
3. Unter **Limits** ein monatliches Ausgabenlimit setzen, z. B. 5 €. So kann nie mehr abgebucht werden.
4. Unter **API Keys** → **Create Key**. Den Schlüssel kopieren. Er wird nur einmal angezeigt.

**b) Funktion bei Supabase anlegen**

1. Supabase → **Edge Functions** → **Deploy a new function** → **Via Editor**.
2. Name: genau `beleg-lesen`.
3. Den Beispielcode löschen und den kompletten Inhalt von `supabase/functions/beleg-lesen/index.ts` einfügen.
4. **Deploy function**.
5. Dann **Edge Functions** → **Secrets** → **Add new secret**:
   - Name: `ANTHROPIC_API_KEY`, Wert: dein Schlüssel aus a).
   - Optional: Name `ANTHROPIC_MODEL`, Wert `claude-haiku-5-5`. Das ist günstiger und reicht für saubere Belege. Ohne diesen Eintrag wird `claude-sonnet-5-5` verwendet, das bei schwierigen Fotos genauer ist.

Die Funktion prüft selbst, dass nur angemeldete Mitglieder eines Lagers sie benutzen.

## Schritt 7: Erste Anmeldung und Daten umziehen

1. Öffne deine App-Adresse.
2. E-Mail und Passwort eintragen → **Neues Konto erstellen**.
3. Du bekommst eine Bestätigungs-Mail. Link anklicken, dann bist du in der App angemeldet.
4. **Neues Lager anlegen**, z. B. „WG Stuttgart“.
5. Oben rechts auf den Lager-Namen klicken → **Sicherung einspielen** → die Datei `Bestand-Sicherung_aus-Claude.json` auswählen.

Fertig: Alle Artikel, Listen, Lieferanten und das Inventar sind da.

> Die Sicherungsdatei zeigt den Stand vom Tag, an dem sie erstellt wurde. Wenn du bis zum Umzug noch in der Claude-Version arbeitest, lass dir kurz vorher eine neue Sicherung erstellen.

## Schritt 8: Freunde einladen

1. Oben rechts auf den Lager-Namen klicken. Dort steht der **Einladungscode** (8 Zeichen).
2. Schick deinen Freunden die App-Adresse und den Code.
3. Sie erstellen ein Konto und wählen **Mit Einladungscode beitreten**.

Ab dann sehen alle dieselben Daten, Änderungen erscheinen bei allen sofort.

**Empfehlung, wenn alle drin sind:** Supabase → **Authentication** → **Sign In / Providers** → **Allow new users to sign up** ausschalten. Dann kann sich niemand Fremdes mehr registrieren. Für neue Freunde schaltest du es kurz wieder ein.

Brauchst du einen neuen Code, z. B. weil der alte in falsche Hände geraten ist, klick im selben Fenster auf **Neuen Code erzeugen**. Das kann nur der Ersteller des Lagers.

## Schritt 9: QR-Etiketten neu drucken

Die QR-Codes zeigen jetzt auf die neue Adresse. Im Bereich **Scan** → **Alle QR-Etiketten als PDF** und die neuen Etiketten drucken. Die alten führen noch zur Claude-Version.

---

## Später: Änderungen an der App

1. Neue `index.html` bekommen (z. B. von Claude).
2. **Deine zwei Werte aus Schritt 3 wieder eintragen.**
3. Auf GitHub im Repository auf `index.html` klicken → Stift-Symbol oder **Add file → Upload files** → die neue Datei hochladen → **Commit changes**.
4. Nach ein bis zwei Minuten ist die neue Version online. Deine Daten bleiben unberührt.

Über **History** im Repository kannst du jederzeit zu einer früheren Version zurück.

## Sicherungen

- In der App oben rechts → **Sicherung herunterladen**. Am besten einmal im Monat und vor großen Änderungen.
- Die Datei enthält alle Daten, auch Bankdaten der Lieferanten. Bewahre sie sicher auf und lade sie **nicht** auf GitHub hoch.
- Mit dieser Datei kannst du jederzeit zu einem anderen Anbieter umziehen.

## Kosten

| Dienst | Kosten |
|---|---|
| GitHub Pages | kostenlos |
| Supabase (Free) | kostenlos für 2 Projekte, 500 MB Daten |
| Anthropic | nur Belegerkennung, ca. 1–3 Cent pro Beleg |

**Wichtig bei Supabase Free:** Ein Projekt, das 7 Tage lang gar nicht benutzt wird, wird pausiert. Die Daten bleiben erhalten. Du bekommst vorher eine Mail und kannst es im Dashboard mit einem Klick wieder starten.

## Wenn etwas nicht klappt

| Problem | Lösung |
|---|---|
| Oben steht „Supabase noch nicht eingerichtet“ | Schritt 3 prüfen: Beide Werte stehen in Anführungszeichen, ohne Leerzeichen davor oder danach. |
| Bestätigungslink führt auf `localhost` | Schritt 5 erledigen und neu registrieren oder „Passwort vergessen“ nutzen. |
| „Die Belegerkennung ist noch nicht eingerichtet“ | Schritt 6 prüfen: Funktion heißt genau `beleg-lesen` und das Secret `ANTHROPIC_API_KEY` ist gesetzt. |
| Belegerkennung meldet „Gerade zu viele Anfragen“ | Guthaben oder Ausgabenlimit bei Anthropic prüfen. |
| Änderungen anderer erscheinen nicht sofort | Seite neu laden. Prüfen, ob Schritt 2 komplett ohne Fehler durchlief (der letzte Teil schaltet die Live-Aktualisierung ein). |
| Seite auf GitHub zeigt 404 | Ein paar Minuten warten. Die Datei muss genau `index.html` heißen. |
