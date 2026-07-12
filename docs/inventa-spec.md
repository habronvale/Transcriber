# Inventa – KI-gestützte Hausinventarisierung
## Technische Spezifikation

| | |
|---|---|
| **Arbeitstitel** | Inventa |
| **Version** | 0.1 (Entwurf zur Review) |
| **Datum** | 2026-07-11 |
| **Autor** | André / Power4Net, erstellt mit Claude |
| **Status** | Offen für Change Requests (siehe Briefing-Dokument) |

> **Hinweis zur Struktur:** Jedes Kapitel und jede wichtige Anforderung trägt eine stabile ID (z. B. `[ARC-2]`, `[UI-3]`). Change Requests und Review-Kommentare referenzieren ausschließlich diese IDs, damit ChatGPT, Claude und menschliche Reviewer eindeutig auf dieselben Stellen zeigen.

---

## 1. Vision & Ziele `[VIS]`

### 1.1 Vision `[VIS-1]`

Eine native iOS-App, mit der das gesamte Hausinventar per Kamera-Rundgang und Sprache erfasst wird – mit so wenig manuellem Aufwand wie irgend möglich. Die KI (Gemini Live) erkennt Gegenstände im Live-Videostream, die App zeigt sie sofort als Vorschlagskarten an, der Nutzer bestätigt per Tap oder korrigiert per Sprache. Bestätigte Items landen strukturiert in Homebox (self-hosted) inklusive freigestelltem Foto, Standort-Hierarchie, Seriennummer und Detailattributen.

### 1.2 Ziele `[VIS-2]`

1. **Minimaler Erfassungsaufwand:** Ein volles Regal in unter 3 Minuten erfassen; ein Werkzeugkasten inkl. Inhalt in unter 90 Sekunden.
2. **Nichts wird falsch abgelegt:** Kein automatischer DB-Write. Alles läuft über eine Staging-Liste mit expliziter Bestätigung (einzeln oder Batch).
3. **Duplikate erkennen statt erzeugen:** Bei jeder Erkennung Live-Abgleich gegen den Bestand (Seriennummer exakt, sonst Fuzzy). Der Nutzer entscheidet: gleiches Gerät / zweites Exemplar.
4. **Container-Inventar:** Werkzeugkästen, Kisten und Koffer werden als Item **und** als Unterstandort geführt; Soll/Ist-Abgleich erkennt fehlende Teile.
5. **Wiederfindbarkeit:** „Wo ist die 10er Nuss in 1/2 Zoll?" wird durch strukturierte Attribute + Homebox-Suche in Sekunden beantwortet.
6. **Datenhoheit:** Bestandsdaten liegen ausschließlich self-hosted (Homebox auf Inge). Cloud-KI nur für die Live-Erkennung, ohne Training und ohne dauerhafte Speicherung (siehe `[PRIV]`).

### 1.3 Nicht-Ziele (v1) `[VIS-3]`

- Kein Multi-User / keine Mandantenfähigkeit (Single-Household).
- Keine Android-Version.
- Kein eigener Inventar-Datenspeicher – Homebox bleibt das führende System (Source of Truth).
- Keine Bewegungshistorie („wer hat wann was entnommen") – Ausbaustufe.
- Kein öffentlicher Zugriff / App Store Release – Distribution via TestFlight/Ad-hoc im eigenen Haushalt.

### 1.4 Design-Prinzipien `[VIS-4]`

| # | Prinzip | Konsequenz |
|---|---|---|
| P1 | **Die Wahrheit liegt in Homebox, nie im KI-Kontext.** | Jede bestätigte Erkennung wird sofort persistiert. Session-Abbrüche sind verlustfrei. |
| P2 | **Staging-first.** | Gemini schreibt nie direkt in die DB, nur in die Staging-Liste der App. |
| P3 | **Eine Hand frei.** | Alle Capture-Interaktionen sind einhändig unten am Screen erreichbar; alles andere geht per Sprache. |
| P4 | **Sprache ergänzt, ersetzt aber nicht.** | Jede Sprachaktion hat ein Touch-Äquivalent (Werkstatt-Lärm, Diskretion). |
| P5 | **Privacy by default.** | Paid Tier / Vertex AI, keine Session Resumption, kein Frame-Upload im Offline-Modus ohne Sync-Freigabe. |
| P6 | **Erweiterbar Richtung lokal.** | Die Erkennungs-Schnittstelle ist so gekapselt, dass später ein lokales Modell (Ollama auf Paul) als Alternative eingehängt werden kann. |

### 1.5 Erfolgskriterien (messbar) `[VIS-5]`

- E1: 20 Items auf einem Regalboden in ≤ 3 Min. erfasst und bestätigt.
- E2: Dedup über Seriennummer: 100 % Treffer bei identischer, lesbar gefilmter Seriennummer.
- E3: Fehlteil-Erkennung bei Werkzeugkästen mit Formeinlage: ≥ 90 % der leeren Fächer korrekt gemeldet.
- E4: Kein einziges Item ohne explizite Nutzerbestätigung in Homebox.
- E5: Vollständiger Session-Abriss (WLAN weg) → 0 Datenverlust bei bereits bestätigten Items, Staging-Liste bleibt lokal erhalten.

---

## 2. Systemarchitektur `[ARC]`

### 2.1 Übersicht `[ARC-1]`

```
┌────────────────────── iPhone (iOS 17+) ──────────────────────┐
│  Inventa App (SwiftUI)                                        │
│  ├─ Kamera-Pipeline (AVFoundation)                            │
│  │    ├─ Video-Frames 1 FPS / 768px  ──► WebSocket            │
│  │    └─ Full-Res Stills (AVCapturePhotoOutput)               │
│  ├─ Audio (Mikro ──► WS, Lautsprecher ◄── WS)                 │
│  ├─ On-Device: VisionKit Subject Lifting, Vision OCR          │
│  ├─ Staging-Store (lokal, SwiftData)                          │
│  └─ Offline-Queue (Video/Audio-Segmente)                      │
└───────────────┬───────────────────────────────┬───────────────┘
                │ WSS (LAN, mTLS optional)      │ HTTPS (LAN)
                ▼                               ▼
┌────────────── Backend „inventa-api" (Docker auf Inge) ────────┐
│  FastAPI (Python 3.12)                                        │
│  ├─ /live   WS-Proxy  ◄──────► Gemini Live API (Vertex AI EU) │
│  ├─ /staging, /confirm, /dedup, /photos  (REST)               │
│  ├─ Dedup-Engine (SerienNr exakt + Fuzzy)                     │
│  ├─ Homebox-Client (REST, Bearer)                             │
│  ├─ Paperless-Client (Beleg-Matching)                         │
│  ├─ Job-Queue (Offline-Batches, rembg-Fallback ► Paul)        │
│  └─ SQLite (Staging/Session-State)                            │
└───────┬───────────────┬───────────────┬───────────────────────┘
        ▼               ▼               ▼
   Homebox (Inge)   Paperless-ngx    n8n (Reports,
   Source of Truth  (Inge)           Fehlteile, Coverage)
                                        │
                                        ▼
                                   Ollama auf Paul
                                   (rembg-Fallback,
                                    spätere lokale Pipeline)
```

### 2.2 Komponenten & Verantwortlichkeiten `[ARC-2]`

| Komponente | Technologie | Verantwortung |
|---|---|---|
| **Inventa App** | Swift 5.10+, SwiftUI, iOS 17+ | Capture-UI, Staging, Bestätigung, On-Device-Bildverarbeitung, Offline-Queue |
| **inventa-api** | Python 3.12, FastAPI, uvicorn, Docker auf Inge | Gemini-Proxy (Credentials bleiben serverseitig), Dedup, Persistenz-Orchestrierung, Foto-Pipeline |
| **Homebox** | bestehende Instanz auf Inge | Führendes Inventarsystem: Standorte, Items, Labels, Custom Fields, Fotos, Mengen |
| **Gemini Live API** | Vertex AI, EU-Region | Objekterkennung im Videostream, Sprach-I/O (Deutsch), Tool-Calls, Soll-Bestückungs-Recherche (Grounding) |
| **Paperless-ngx** | bestehende Instanz | Beleg-Matching (Kaufdatum, Preis, Garantie) |
| **rembg/BiRefNet** | Docker auf Paul (GPU) | Server-Fallback fürs Freistellen, wenn On-Device Subject Lifting scheitert |
| **n8n** | bestehende Instanz | Reports (Fehlteile, Duplikate, Coverage), Paperless-Matching-Workflow. Paperless-Credential: ID `nqeSr7OJle6brKTe`, Name „Paperless (n8n)" |

### 2.3 Architektur-Entscheidungen `[ARC-3]`

| ID | Entscheidung | Begründung |
|---|---|---|
| A1 | **App ↔ Backend ↔ Gemini** (Proxy) statt App ↔ Gemini direkt | Google-Credentials verlassen nie das LAN; Google empfiehlt Server-to-Server; Backend kann Frames/Tool-Calls mitschneiden (Staging, Dedup) ohne zweiten Upload. |
| A2 | **Keine Gemini Session Resumption** | Resumption cached Video/Audio bis 24 h bei Google. Stattdessen: Bei Verbindungsabriss baut das Backend eine frische Session auf und „re-seedet" sie mit kompaktem Text-Kontext (aktueller Standort, Container-Modus, letzte 10 Staging-Items). Zero-Retention-freundlich, P1-konform. |
| A3 | **Context Window Compression aktiv** | Audio+Video-Sessions sind ohne Compression auf ~2 Min. begrenzt; mit Compression zeitlich unbegrenzt. Verlust älterer Kontexte ist unkritisch (P1: Wahrheit liegt im Backend). |
| A4 | **SQLite im Backend** statt Postgres | Single-User, geringes Volumen, keine Ops-Last. Staging ist transient; Langzeitdaten liegen in Homebox. |
| A5 | **Backend nur im LAN** (`int.p4n-srv.de`), kein Public Endpoint | Angriffsfläche minimal. Erfassung außerhalb des WLANs → Offline-Queue `[IOS-6]`. |
| A6 | **Erkennungs-Provider als Interface** | `RecognitionProvider`-Protokoll im Backend; v1: GeminiLiveProvider. Später: LocalProvider (Ollama/gemma-Vision auf Paul) ohne App-Änderung. |

---

## 3. Datenschutz & Sicherheit `[PRIV]`

### 3.1 Anforderungen `[PRIV-1]`

| ID | Anforderung |
|---|---|
| PR1 | Gemini ausschließlich über **bezahltes Tier / Vertex AI** nutzen – dort werden Kundendaten laut Google-Bedingungen (Training Restriction) nicht zum Training verwendet. Free Tier ist verboten. |
| PR2 | **EU-Region** in Vertex AI wählen (Region beim Implementierungs-Spike prüfen: Live-Modelle sind nicht in jeder Region/„global" verfügbar). |
| PR3 | **Session Resumption deaktiviert lassen** (Default), da sonst Prompts/Video/Audio bis 24 h bei Google gecached werden. |
| PR4 | Prüfen/Beantragen der **Abuse-Monitoring-Ausnahme** für Zero Data Retention (Vertex, optional – für einen Privathaushalt vermutlich Nice-to-have). |
| PR5 | Google-Credentials (Service Account) liegen **nur im Backend** (Docker Secret / env), nie in der App. |
| PR6 | App speichert Backend-URL + API-Token im **iOS Keychain**. |
| PR7 | Offline-Aufnahmen (Video/Audio) bleiben lokal, bis der Nutzer den Sync **explizit** startet; danach werden lokale Segmente gelöscht. |
| PR8 | Fotos in Homebox enthalten keine EXIF-GPS-Daten (Strip beim Upload). |
| PR9 | Backend-API: Bearer-Token (statisch, in Vaultwarden abgelegt), Rate-unkritisch da LAN-only. |

### 3.2 Datenflüsse `[PRIV-2]`

| Daten | Ziel | Verbleib |
|---|---|---|
| Live-Video (1 FPS, 768 px) + Mikrofon | Gemini Live (Vertex EU) | Nur In-Flight-Verarbeitung; kein Training (paid), keine Resumption-Caches |
| Full-Res-Fotos | Backend → Homebox | Dauerhaft, self-hosted |
| Staging-Metadaten | Backend SQLite | Bis Bestätigung/Verwurf, danach Purge (7 Tage) |
| Sprach-Transkripte | Backend-Log (optional, Debug) | Default: aus |

---

## 4. Gemini-Live-Integration `[AI]`

### 4.1 Session-Konfiguration `[AI-1]`

- **Modell:** aktuelles Live-Modell mit nativem Audio und Function Calling. Kandidaten zum Spezifikationszeitpunkt: `gemini-3.1-flash-live-preview` (Gemini Developer API) bzw. `gemini-live-2.5-flash-native-audio` (Vertex). **Beim Implementierungs-Spike `[PHA-P0]` die aktuell verfügbare Modell-ID und Region verifizieren.**
- **Modalitäten:** Input: Audio + Video-Frames (1 FPS, 768×768 empfohlen) + Text (Re-Seed). Output: Audio (Deutsch) + Transkript.
- **Context Window Compression:** aktiviert (Sliding Window), damit Sessions länger als 2 Min. laufen.
- **Session-Lifecycle:** WebSocket-Verbindungen sind auf ~10 Min. begrenzt → Backend rotiert Verbindungen proaktiv bei 8 Min. und re-seedet (siehe A2). Für die App ist das transparent (kurzer „Verbinde neu…"-Hinweis, Capture läuft weiter, Frames werden 2–3 s gepuffert).
- **System Instruction (Kernaussagen, finaler Prompt in P1 iteriert):**
  - Rolle: Inventar-Assistent, antwortet knapp auf Deutsch.
  - Erkenne physische Gegenstände; für jedes eindeutig erkannte Item genau **ein** `stage_item`.
  - Sprich nur, wenn: Rückfrage nötig, Duplikat gemeldet wird, Container-Kontext wechselt oder der Nutzer dich anspricht. Kein Dauerkommentar.
  - Seriennummern nur übernehmen, wenn sicher lesbar; sonst `serial_number: null` und ggf. bitten, näher ranzugehen.
  - Nutzerkorrekturen („nein, das ist ein Schlagschrauber") → `update_staged_item`, niemals Diskussion.
  - Bei geöffnetem Container: erkannte Teile dem Container zuordnen; auf Anforderung Soll/Ist-Abgleich via `report_set_completeness`.

### 4.2 Tool-Schemas (Function Declarations) `[AI-2]`

Alle Tools werden vom Backend deklariert; Tool-Calls landen im Backend, das antwortet mit Tool-Responses (z. B. Dedup-Ergebnis), die das Modell versprachlichen kann.

```json
[
  {
    "name": "set_location",
    "description": "Setzt den aktuellen Erfassungs-Standort. Wird aufgerufen, wenn der Nutzer einen Ort ansagt (z. B. 'Werkstatt, Regal links, Boden 2').",
    "parameters": {
      "type": "object",
      "properties": {
        "path": {
          "type": "array", "items": {"type": "string"},
          "description": "Hierarchie von grob nach fein, z. B. ['EG','Werkstatt','Regal links','Boden 2']"
        }
      },
      "required": ["path"]
    }
  },
  {
    "name": "stage_item",
    "description": "Meldet ein neu erkanntes Item zur Staging-Liste. Pro physischem Gegenstand genau ein Aufruf.",
    "parameters": {
      "type": "object",
      "properties": {
        "name": {"type": "string", "description": "Kurzer Titel, z. B. 'Makita Akkuschrauber DDF484'"},
        "category": {"type": "string", "description": "Grobkategorie, z. B. 'Elektrowerkzeug', 'Farbe', 'Nuss'"},
        "brand": {"type": "string"},
        "model": {"type": "string"},
        "serial_number": {"type": "string", "description": "Nur wenn sicher lesbar, sonst weglassen"},
        "quantity": {"type": "integer", "description": "Default 1; bei zählbaren Gleichteilen die erkannte Anzahl"},
        "attributes": {
          "type": "object",
          "description": "Strukturierte Details, z. B. {\"antrieb\":\"1/2 Zoll\",\"groesse\":\"10 mm\",\"fuellgrad\":\"halb voll\",\"farbe\":\"lila\",\"zustand\":\"gebraucht\"}"
        },
        "confidence": {"type": "number", "description": "0..1 Selbsteinschätzung"},
        "needs_review": {"type": "boolean", "description": "true, wenn Rückfrage sinnvoll wäre"}
      },
      "required": ["name", "category", "confidence"]
    }
  },
  {
    "name": "update_staged_item",
    "description": "Korrigiert oder ergänzt ein Staging-Item nach Nutzeraussage (z. B. 'die lila Dose ist halb voll').",
    "parameters": {
      "type": "object",
      "properties": {
        "staging_id": {"type": "string"},
        "fields": {"type": "object", "description": "Nur die geänderten Felder"}
      },
      "required": ["staging_id", "fields"]
    }
  },
  {
    "name": "discard_staged_item",
    "description": "Verwirft ein Staging-Item (Fehlerkennung).",
    "parameters": {
      "type": "object",
      "properties": {"staging_id": {"type": "string"}, "reason": {"type": "string"}},
      "required": ["staging_id"]
    }
  },
  {
    "name": "open_container",
    "description": "Aktiviert den Container-Modus: alle folgenden stage_item-Aufrufe gehören in diesen Behälter.",
    "parameters": {
      "type": "object",
      "properties": {
        "container_staging_id": {"type": "string", "description": "Staging-ID des Behälter-Items, falls gerade erfasst"},
        "container_name": {"type": "string", "description": "Alternativ Klarname eines Bestands-Containers, z. B. 'Hazet 1/2-Zoll-Kasten'"}
      }
    }
  },
  {
    "name": "close_container",
    "description": "Beendet den Container-Modus; Standortkontext gilt wieder.",
    "parameters": {"type": "object", "properties": {}}
  },
  {
    "name": "report_set_completeness",
    "description": "Soll/Ist-Abgleich für ein Set (z. B. Steckschlüsselsatz). Soll-Liste aus Produktwissen/Grounding, Ist aus dem Bild.",
    "parameters": {
      "type": "object",
      "properties": {
        "container_staging_id": {"type": "string"},
        "set_reference": {"type": "string", "description": "Herstellerbezeichnung des Sets"},
        "expected": {"type": "array", "items": {"type": "string"}},
        "present": {"type": "array", "items": {"type": "string"}},
        "missing": {"type": "array", "items": {"type": "string"}},
        "uncertain": {"type": "array", "items": {"type": "string"}}
      },
      "required": ["container_staging_id", "present", "missing"]
    }
  },
  {
    "name": "note",
    "description": "Freitext-Notiz des Nutzers zum aktuellen Standort oder Item.",
    "parameters": {
      "type": "object",
      "properties": {"text": {"type": "string"}, "staging_id": {"type": "string"}},
      "required": ["text"]
    }
  }
]
```

### 4.3 Tool-Response-Verhalten `[AI-3]`

- **`stage_item` →** Backend führt sofort Dedup aus (`[BE-4]`) und antwortet: `{"staging_id":"…","duplicates":[{"item_id":"…","name":"…","location":"Werkstatt / Regal 2","serial_match":true,"quantity":1}]}`. Bei `serial_match:true` sagt das Modell z. B.: „Den Makita mit dieser Seriennummer hast du schon erfasst – Werkstatt, Regal 2. Zweites Gerät oder derselbe?"
- **`set_location` →** Backend legt fehlende Homebox-Standorte **noch nicht** an (erst bei Confirm), merkt aber den Pfad im Session-State.
- **`report_set_completeness` →** fehlende Teile erzeugen Staging-Items mit Label `fehlt` und `quantity 0` (siehe `[DATA-4]`).

### 4.4 Kein Frontier-Lock-in `[AI-4]`

Die App kennt nur das Backend-Protokoll (`[BE-2]`). Ein späterer Wechsel auf ein anderes Live-Modell oder eine lokale Pipeline (Frames + Whisper + gemma4:26b auf Paul) betrifft ausschließlich den `RecognitionProvider` im Backend.

---

## 5. iOS-App `[IOS]`

### 5.1 Tech-Stack `[IOS-1]`

| Bereich | Wahl |
|---|---|
| Sprache/UI | Swift 5.10+, SwiftUI, MVVM + `@Observable` |
| Min. iOS | 17.0 (VisionKit Subject Lifting API, ImageAnalyzer) |
| Kamera | AVFoundation: `AVCaptureVideoDataOutput` (Stream-Frames) + `AVCapturePhotoOutput` (Full-Res-Stills) an derselben Session |
| Freistellen | VisionKit `ImageAnalyzer` / Subject Lifting on-device; Fallback rembg auf Paul `[BE-6]` |
| OCR-Assist | Vision `VNRecognizeTextRequest` (accurate) auf Full-Res-Frames für Seriennummern `[IOS-4]` |
| Audio | AVAudioEngine (16 kHz PCM Upstream, 24 kHz Playback), Echo Cancellation via VoiceProcessingIO |
| Netzwerk | `URLSessionWebSocketTask` (Live-Kanal), `URLSession` REST |
| Lokaler Store | SwiftData (Staging-Cache, Offline-Queue, Settings) |
| Haptik | CoreHaptics (Erkennung: leichter Tick; Duplikat: Doppel-Tick; Fehler: Buzz) |
| Distribution | TestFlight (intern) oder Ad-hoc; kein App-Store-Review nötig |

### 5.2 Kamera-Pipeline `[IOS-2]`

1. `AVCaptureSession` mit `.photo`-Preset; VideoDataOutput liefert BGRA-Frames.
2. Downsampler: 1 Frame/s → 768 px lange Kante → JPEG (Qualität 0.6) → WS an Backend (`frame`-Message).
3. Parallel Ringpuffer der letzten 3 s Full-Res-Frames (für „bester Frame").
4. Bei `stage_item`-Event vom Backend: App wählt aus dem Ringpuffer den schärfsten Frame (Laplacian-Varianz), triggert zusätzlich `AVCapturePhotoOutput`-Still, führt Subject Lifting aus und lädt Original + Freisteller via REST hoch (`[BE-3]/photos`).
5. Belichtung/Fokus: Tap-to-Focus; Taschenlampen-Toggle für dunkle Schubladen.

### 5.3 Subject Lifting `[IOS-3]`

- `ImageAnalyzer` mit `.visualLookUp`-Konfiguration auf dem Still; extrahiertes Subjekt als PNG mit Alpha.
- Wenn mehrere Subjekte erkannt: dasjenige mit größter Überlappung zur Gemini-Bounding-Box (falls geliefert), sonst größtes Subjekt.
- Scheitert Lifting (kein Subjekt, < 10 % Bildfläche): Original hochladen mit Flag `lifting_failed:true` → Backend-Fallback rembg auf Paul.

### 5.4 Seriennummern-Assist `[IOS-4]`

Der 1-FPS/768-px-Stream ist für kleine Typenschilder oft zu schwach. Deshalb On-Device-Unterstützung:

- Kontinuierlicher `VNRecognizeTextRequest` (throttled, 2/s) auf Full-Res-Frames.
- Kandidaten-Filter per Regex (alphanumerisch ≥ 6 Zeichen, typische Muster `S/N`, `Ser.-Nr.`, `SN:`).
- Treffer werden dem nächsten `stage_item` zeitlich zugeordnet (±2 s) und als `serial_candidate` mitgesendet; Backend/Gemini bestätigt oder verwirft.
- UI: erkannte Seriennummer erscheint als Chip auf der Staging-Karte, antippbar zum Editieren.

### 5.5 Staging-Store & Sync `[IOS-5]`

- Staging-Items leben in SwiftData **und** im Backend (Backend führt; App cached für Offline-Anzeige).
- Confirm (einzeln oder Batch) → REST `POST /confirm` → Backend schreibt Homebox → App markiert Item „synced" mit Homebox-ID.
- Konfliktregel: Backend gewinnt; App zeigt Diffs nur an.

### 5.6 Offline-Modus (Schuppen/Keller) `[IOS-6]`

- Erkennt die App > 3 s keine Backend-Verbindung: Banner „Offline-Erfassung" + Aufnahme-Button.
- Aufnahme: Video (1080p, 30 fps) + Audio als Segmente (max. 3 Min.) in App-Container.
- Zurück im WLAN: „Jetzt verarbeiten" → Upload an `POST /batch`; Backend extrahiert Frames (1 fps), schickt sie mit Audio-Transkript sequenziell durch dieselbe Erkennungslogik; Ergebnis erscheint als normale Staging-Liste zur Review.
- Segmente werden nach erfolgreicher Verarbeitung lokal gelöscht (PR7).

---

## 6. UI/UX `[UI]`

### 6.1 Designsprache `[UI-1]`

- **Charakter:** Werkstatt-tauglich, hoher Kontrast, ruhig. Die Kamera ist der Held – UI-Chrome minimal, als Overlays auf dem Sucher.
- **Farb-Token:** `Ink #0E1116` (Flächen dunkel), `Bone #F5F2EC` (Light-Mode-Flächen), `Signal #FF6A00` (Bestätigen/CTA – Warnorange wie auf Werkzeug), `Steel #8E979F` (Sekundär), `Moss #3E7C4F` (synced), `Alert #D64545` (fehlt/Fehler). Ein Akzent, konsequent: Orange nur für „in die DB übernehmen".
- **Typo:** SF Pro (Text/Display) + **SF Mono für alle IDs, Seriennummern, Mengen und Maße** – die Monospace-Behandlung technischer Werte ist das visuelle Erkennungszeichen der App.
- **Materialien:** `ultraThinMaterial`-Overlays über dem Kamerabild; auf iOS 26 automatisch Liquid-Glass-Anmutung, auf iOS 17 klassisches Blur – kein eigenes Skinning.
- **Signature-Element:** die **Staging-Karte, die aus dem Sucher „herausfällt"** – bei Erkennung friert ein Mini-Thumbnail des Objekts ein, fliegt animiert in den Tray unten und tickt haptisch. Erfassung fühlt sich an wie Einsammeln.
- **Dark Mode:** Default im Capture (Keller/Schuppen), systemweit adaptiv.
- **Accessibility:** Touch-Targets ≥ 44 pt, Dynamic Type bis XL, VoiceOver-Labels auf allen Karten, Reduced Motion respektiert (Karten faden statt fliegen).

### 6.2 Screens `[UI-2]`

**S-1 Home / Dashboard**
Räume als Karten mit Coverage-Ring („Werkstatt · 4/6 Regale"), zuletzt erfasste Items, Button „Erfassung starten", Reiter: Erfassen · Bestand · Reports · Einstellungen. Bestand-Reiter ist eine eingebettete, native Suche gegen Homebox (Read-only-Detail mit „In Homebox öffnen").

**S-2 Capture (Kernscreen, einhändig)**
- Vollbild-Sucher.
- Oben: Standort-Chip (`EG › Werkstatt › Regal links › Boden 2`), antippbar → S-5. Bei aktivem Container-Modus stattdessen ein deutlich sichtbares Banner `📦 Im Kasten: Hazet 1/2"` mit „Schließen".
- Unten: horizontaler **Staging-Tray** (letzte 3–4 Karten). Karte: Thumbnail (freigestellt), Titel, Attribute-Chips, Confidence-Punkt. Gesten: **Tap = bestätigen** (orange Blitz + Haken), **Swipe down = verwerfen**, **Long-Press = S-4 Detail**.
- Rechts unten (Daumenzone): Mic-Status (Waveform bei Nutzersprache), Taschenlampe, Pause.
- Duplikat-Fall: Karte klappt eine **Match-Karte** darüber auf („Bereits erfasst · Werkstatt Regal 2 · Menge 1") mit zwei Buttons: `Gleiches Teil` / `+1 Exemplar`.

**S-3 Staging-Review (Bottom Sheet, aufziehbar)**
Alle offenen Staging-Items der Session, gruppiert nach Standort/Container. Multi-Select, „Alle bestätigen (12)", Einzelverwurf, Sortierung nach Confidence (Unsichere zuerst).

**S-4 Item-Detail (Edit)**
Foto (Original/Freisteller umschaltbar, Neu aufnehmen), Titel, Kategorie, Marke/Modell, Seriennummer (Mono, mit OCR-Kandidaten), Menge-Stepper, Attribut-Editor (Key-Value-Chips), Standort/Container, Notiz, Labels. Unten: `Bestätigen` / `Verwerfen`.

**S-5 Standorte**
Baum-Ansicht der Homebox-Standorte, Schnellanlage neuer Knoten, „Hierher erfassen".

**S-6 Reports**
Fehlteile (aus `fehlt`-Labels, gruppiert nach Set), Duplikat-Kandidaten, Coverage pro Raum, „Falsch gelagert"-Vorschläge (Ausbaustufe, via n8n/gemma). Export: Fehlteile als Einkaufsliste (Reminders-Share-Sheet), Hausrat-Report als PDF (Ausbaustufe).

**S-7 Einstellungen**
Backend-URL + Token (Keychain), Verbindungstest, Privacy-Status (Tier, Region, Resumption aus – read-only Anzeige vom Backend), Sprachausgabe an/aus + Lautstärke, Offline-Queue-Verwaltung, Standard-Labels.

**iPad:** dieselbe App als Universal-Target. Auf iPad ist S-3/S-4 als permanente Split-View-Spalte neben dem Sucher sichtbar (Review-Station); Capture bleibt iPhone-optimiert. Kein separates iPad-Projekt.

### 6.3 Sprachinteraktion `[UI-3]`

- Gemini spricht Deutsch, kurz, nur anlassbezogen (`[AI-1]`).
- Nutzerphrasen (Beispiele, kein starres Grammar): „Werkstatt, Regal links, Boden zwei" · „öffne den Kasten" · „Kasten zu" · „die lila Dose ist halb voll" · „nein, das ist ein Schlagschrauber" · „was fehlt in dem Kasten?" · „verwirf das letzte".
- Jede Sprachaktion spiegelt sich sofort sichtbar in UI-State (Chip, Banner, Karte) – Vertrauen durch Sichtbarkeit.

---

## 7. Backend `[BE]`

### 7.1 Deployment `[BE-1]`

Docker-Container `inventa-api` auf Inge (Compose), Ports nur im LAN. Konfiguration via env: `GOOGLE_APPLICATION_CREDENTIALS`, `VERTEX_REGION`, `HOMEBOX_URL/TOKEN`, `PAPERLESS_URL/TOKEN`, `REMBG_URL` (Paul), `API_TOKEN`.

### 7.2 API (App ↔ Backend) `[BE-2]`

**WebSocket `/live`** – bidirektional, JSON-Messages:

| Richtung | Message | Inhalt |
|---|---|---|
| App→BE | `frame` | JPEG base64, ts |
| App→BE | `audio` | PCM-Chunk 16 kHz |
| App→BE | `serial_candidate` | OCR-Kandidat + ts `[IOS-4]` |
| App→BE | `ui_action` | tap_confirm / swipe_discard / open_container / close_container / set_location (Touch-Äquivalente) |
| BE→App | `audio_out` | PCM 24 kHz (Gemini-Stimme) |
| BE→App | `staged` | vollständiges Staging-Item inkl. Dedup-Matches |
| BE→App | `updated` / `discarded` | Staging-Änderungen |
| BE→App | `location_changed` / `container_opened` / `container_closed` | Kontext-Events |
| BE→App | `session_state` | reconnecting / ready / error |

**REST:**

| Endpoint | Zweck |
|---|---|
| `POST /session` | Session starten (liefert WS-URL + Session-ID) |
| `GET /staging?session=…` | Staging-Liste |
| `POST /confirm` | `{staging_ids:[…]}` → Homebox-Write, liefert Homebox-IDs |
| `POST /photos/{staging_id}` | Multipart: original, lifted (optional), `lifting_failed` |
| `POST /batch` | Offline-Segmente (Video+Audio) zur asynchronen Verarbeitung |
| `GET /reports/missing` · `/reports/duplicates` · `/reports/coverage` | Reports für S-6 |
| `GET /health` · `GET /privacy` | Status; Privacy-Anzeige für S-7 |

### 7.3 Confirm-Pipeline `[BE-3]`

1. Standort-Pfad auflösen: fehlende Homebox-Locations anlegen (idempotent, Name-Match je Ebene).
2. Container-Fall: Behälter-Item anlegen **und** gleichnamigen Unterstandort (Konvention `[DATA-3]`), Querverweis in Beschreibung + Custom Field `container_location_id`.
3. Item anlegen: Name, Beschreibung, Menge, Seriennummer (natives Feld), Labels, Custom Fields (`[DATA-2]`), Foto-Attachments (Freisteller als Primärbild, Original als zweites).
4. Paperless-Match (async): Suche nach Marke+Modell in Rechnungen → bei Treffer Kaufdatum/Preis als Custom Fields + Paperless-Link in Beschreibung.
5. Antwort an App mit Homebox-Item-URL.

### 7.4 Dedup-Engine `[BE-4]`

Reihenfolge bei jedem `stage_item`:
1. **Seriennummer exakt** (normalisiert: Uppercase, ohne Sonderzeichen) → harter Treffer.
2. **Fuzzy:** gleiche Kategorie + (Marke ODER Modell) + Token-Ähnlichkeit Name ≥ 0.75 (RapidFuzz) → weiche Treffer (max. 3), sortiert nach Standortnähe (gleicher Raum zuerst).
3. Innerhalb derselben Session zusätzlich Abgleich gegen unbetätigte Staging-Items (verhindert Doppelmeldung bei erneutem Schwenk).
Antwort geht als Tool-Response an Gemini **und** als `staged`-Message an die App.

### 7.5 Batch-Verarbeitung (Offline) `[BE-5]`

ffmpeg: 1 fps Frames + Audiospur → Transkription (Gemini oder lokal WhisperKit-kompatibel, konfigurierbar) → Frames+Transkript-Fenster sequenziell an denselben Provider mit identischen Tools → Staging wie live. Fortschritt via `GET /batch/{id}`.

### 7.6 Freistellen-Fallback `[BE-6]`

`REMBG_URL` (Container auf Paul, Modell BiRefNet-general). Nur aufgerufen bei `lifting_failed:true`. Ergebnis ersetzt Primärbild in Staging.

### 7.7 n8n-Anbindung `[BE-7]`

- Backend feuert Webhooks: `item.confirmed`, `set.missing_parts`, `session.completed`.
- n8n-Workflows: Fehlteil-Einkaufsliste, wöchentlicher Coverage-Report, Paperless-Matching-Fallback (nutzt Paperless-Credential ID `nqeSr7OJle6brKTe`, „Paperless (n8n)").
- Spätere „Falsch gelagert"-Analyse: n8n zieht Bestand via Homebox-API, clustert Kategorien je Standort mit gemma4:26b auf Paul (nicht gemma4:31b) und meldet Ausreißer.

---

## 8. Datenmodell `[DATA]`

### 8.1 Staging-Item (Backend/App) `[DATA-1]`

```json
{
  "staging_id": "stg_9f3a",
  "session_id": "ses_2026-07-11_01",
  "state": "staged | confirmed | discarded | synced",
  "name": "Makita Akkuschrauber DDF484",
  "category": "Elektrowerkzeug",
  "brand": "Makita",
  "model": "DDF484",
  "serial_number": "081226B-4711",
  "serial_source": "gemini | ocr | user | null",
  "quantity": 1,
  "attributes": {"antrieb": null, "groesse": null, "fuellgrad": null, "zustand": "gebraucht"},
  "labels": [],
  "location_path": ["EG","Werkstatt","Regal links","Boden 2"],
  "container_ref": null,
  "photos": {"original": "…", "lifted": "…", "lifting_failed": false},
  "dedup": [{"homebox_item_id": "…", "match": "serial|fuzzy", "score": 1.0}],
  "confidence": 0.92,
  "homebox_item_id": null,
  "created_at": "…", "confirmed_at": null
}
```

### 8.2 Homebox-Mapping `[DATA-2]`

| Staging-Feld | Homebox |
|---|---|
| name | Item Name |
| category | Label `kat:<Kategorie>` |
| brand/model | Manufacturer / Model Number (native Felder) |
| serial_number | Serial Number (natives Feld) |
| quantity | Quantity |
| attributes.* | Custom Fields: `Antrieb`, `Größe`, `Füllgrad`, `Zustand` (+ dynamisch weitere) |
| location_path | verschachtelte Locations |
| photos | Attachments (lifted = primary) |
| Paperless-Treffer | Custom Fields `Kaufdatum`, `Kaufpreis` + Link in Description |
| Notizen | Description |

### 8.3 Container-Konvention `[DATA-3]`

Ein Behälter erzeugt **zwei** Homebox-Objekte mit identischem Namen:
1. **Item** „Hazet Steckschlüsselsatz 1/2″ (900er)" am physischen Standort (Regal-Boden), Label `container`.
2. **Location** gleichen Namens als Kind desselben Regal-Bodens; Inhalts-Items liegen darin.
Custom Field `container_location_id` auf dem Item verlinkt beide. **Spike-Auftrag `[PHA-P0]`:** prüfen, ob die aktuell eingesetzte Homebox-Version (sysadminsmedia-Fork) native Parent-Item-Beziehungen unterstützt – falls ja, wird diese Konvention durch das native Feature ersetzt (nur Backend-Mapping ändert sich).

### 8.4 Fehlteile `[DATA-4]`

Fehlende Set-Teile werden als reguläre Items im Container-Standort angelegt: `quantity 0`, Label `fehlt`, Attribute vollständig (z. B. Nuss, 10 mm, 1/2″). Dadurch: (a) Einkaufsliste = Homebox-Filter auf Label `fehlt`; (b) die Suche „10 mm" zeigt sowohl vorhandene als auch fehlende Exemplare mit Antriebsgröße – exakt der Anwendungsfall „habe ich irgendwo eine passende 10er?".

### 8.5 Attribut-Taxonomie Werkzeug (Startset) `[DATA-5]`

`antrieb` (1/4″, 3/8″, 1/2″, 3/4″, 1″) · `groesse` (mm/Zoll) · `typ` (Nuss, Ratsche, Verlängerung, Gelenk, Bit …) · `fuellgrad` (voll, halb, fast leer, leer) · `farbe` · `zustand` (neu, gebraucht, defekt). Erweiterbar; Gemini darf neue Keys vorschlagen, Backend normalisiert (lowercase, Synonym-Map).

---

## 9. Kern-Workflows `[FLOW]`

**W1 – Raum-Erfassung:** Capture starten → „Werkstatt, Regal links, Boden zwei" → Chip aktualisiert → langsam schwenken → Karten fallen in den Tray → Tap-Tap-Tap bestätigen (oder am Ende Batch in S-3) → Boden fertig → „Boden drei" → weiter.

**W2 – Werkzeugkasten:** Kasten geschlossen ins Bild → `stage_item` (Marke/Modell/S-N) → bestätigen → „öffne den Kasten" → Banner `📦` → Kasten offen filmen (1 ruhiges Foto reicht meist) → Teile werden gestaged, dem Kasten zugeordnet → „was fehlt?" → `report_set_completeness` → Gemini: „Es fehlt die 10er Nuss." → Fehlteil-Karte (rot) → bestätigen → „Kasten zu".

**W3 – Duplikat:** Akkuschrauber im Esszimmer gefilmt → Serial-Match → Match-Karte „Bereits erfasst · Werkstatt Regal 2" → Optionen: `Gleiches Teil` (kein neues Item; optional „Standort aktualisieren?" – Ausbaustufe) / `+1 Exemplar` (Quantity+1 oder neues Item bei abweichender S-N).

**W4 – Detail per Sprache:** Farbdosen im Bild → 4 Karten → „die lila ist halb voll" → `update_staged_item` → Chip `Füllgrad: halb voll` erscheint auf der lila Karte.

**W5 – Korrektur:** „Nein, das ist ein Schlagschrauber" → Karte ändert Titel+Kategorie, kein Write bis Bestätigung.

**W6 – Offline:** Schuppen ohne WLAN → Banner → Aufnahme → zuhause „Jetzt verarbeiten" → Staging-Review wie gewohnt.

---

## 10. Phasenplan `[PHA]`

| Phase | Inhalt | Exit-Kriterium |
|---|---|---|
| **P0 – Spikes (1 Wo.)** | (a) Vertex Live: Modell-ID, EU-Region, DE-Audio, Function Calling e2e; (b) Homebox-API: Locations/Items/Custom Fields/Attachments, Parent-Item-Check `[DATA-3]`; (c) VisionKit Lifting + Vision-OCR auf Testfotos; (d) Kostenmessung 10-Min-Session | Alle vier Spikes grün dokumentiert, Modell/Region fixiert |
| **P1 – MVP Capture (2–3 Wo.)** | S-2 Capture, WS-Proxy, `set_location`/`stage_item`/`update`/`discard`, Staging-Tray, Confirm→Homebox mit Foto (Lifting on-device), S-7 minimal | W1 + W4 + W5 laufen; E1, E4 erfüllt |
| **P2 – Dedup & Container (2 Wo.)** | Dedup-Engine, Match-Karte, Serial-OCR-Assist, Container-Modus, Doppel-Modellierung | W2 (ohne Soll/Ist), W3; E2 erfüllt |
| **P3 – Sets & Reports (2 Wo.)** | `report_set_completeness` + Grounding, Fehlteil-Items, S-3 Batch-Review, S-6 Reports, n8n-Webhooks | W2 komplett; E3 erfüllt |
| **P4 – Komfort (fortlaufend)** | Offline-Queue + Batch, Paperless-Match, iPad-Split-View, Coverage, rembg-Fallback, Hausrat-PDF, Einkaufslisten-Export | W6; Paperless-Treffer sichtbar |

**Empfohlene Umsetzung:** Backend + Prompts mit Claude Code entwickeln (Repo `inventa`, Ordner `/ios`, `/backend`, `/prompts`, `/docs`); iOS in Xcode 16+, Claude Code als Pair für SwiftUI/AVFoundation.

---

## 11. Test & Abnahme `[TEST]`

- **T1 Golden-Set:** 30 fotografierte Referenz-Items (Werkzeug, Farben, Elektronik, Kleinteile) mit erwarteten Feldern; Regressionslauf gegen den Provider bei jedem Prompt-Change (Skript im Repo).
- **T2 Dedup:** 5 Paare identischer S-N, 5 Fuzzy-Paare, 5 Nicht-Paare → Precision ≥ 0.95, keine False-Positive-Auto-Merges (gibt es designbedingt nicht: immer Nutzerentscheid).
- **T3 Container:** 3 reale Kästen (1/2″, 3/4″, Bit-Set) mit bekannt fehlenden Teilen → E3.
- **T4 Robustheit:** WLAN-Cut mitten in Session → E5; Backend-Neustart → App reconnect < 10 s.
- **T5 Usability:** kompletter Raum (Werkstatt) durch André, Stoppuhr, danach CR-Runde.
- **T6 Privacy-Audit:** Netzwerk-Mitschnitt einer Session → ausschließlich Backend↔Vertex-Traffic, Resumption-Flag aus, Region EU.

---

## 12. Kosten (Schätzung) `[COST]`

- Live-Input taktet grob mit ~258 Token/s Video + ~25 Token/s Audio ≈ ~1 Mio. Input-Token pro Scan-Stunde, plus geringe Output-/Tool-Token. Bei Flash-Klasse-Preisen liegt eine Stunde aktives Scannen im **niedrigen einstelligen Euro-Bereich**; eine komplette Haus-Ersterfassung (geschätzt 6–10 h) entsprechend darunter/um die 10–30 €. **P0 verifiziert mit aktueller Preisliste und realer Messung** – Preise ändern sich häufig.
- Laufende Kosten danach minimal (nur Nacherfassung). Homebox/Backend/rembg: 0 € (vorhandene Hardware).

---

## 13. Risiken & offene Punkte `[RISK]`

| ID | Risiko/Frage | Mitigation |
|---|---|---|
| R1 | Live-Modell-IDs/Preview-APIs ändern sich | Provider-Interface (A6), Modell-ID als Config, P0-Verifikation |
| R2 | Erkennungsqualität bei Kleinteilen (Schrauben lose) | Erwartung setzen: Kleinteile als Sammel-Item mit Menge/Kiste, nicht einzeln |
| R3 | Soll-Bestückung unbekannter/alter Sets nicht recherchierbar | Fallback: nur leere Fächer melden („1 Fach leer, Teil unbekannt"), Nutzer benennt per Sprache |
| R4 | 2 iPhone-Hände belegt (Item + Phone) | Sprache first (P4), Stativ-/Umhänge-Option erwähnen; Kernaktionen Daumenzone |
| R5 | Homebox-Fork-Entwicklung (Parent Items, API-Änderungen) | P0-Spike, API-Client isoliert, Versions-Pin |
| R6 | WLAN-Löcher | Offline-Queue `[IOS-6]` |
| R7 | Gemini spricht zu viel / stört | System-Prompt „nur anlassbezogen", UI-Toggle Sprachausgabe |
| O1 | App-Name final („Inventa" = Arbeitstitel) | Entscheidung André (Briefing F-3) |
| O2 | Vertex vs. Gemini Developer API (paid) | Beide erfüllen PR1; Vertex bietet EU-Region + stärkere Vertragslage → Empfehlung Vertex, finale Entscheidung nach P0-Kostenvergleich |

---

## 14. Glossar `[GLOS]`

**Staging** – Zwischenpuffer erkannter Items vor der Bestätigung. · **Container-Modus** – Erfassungszustand, in dem Items einem Behälter statt dem Raum-Standort zugeordnet werden. · **Soll/Ist-Diff** – Abgleich Hersteller-Bestückungsliste gegen sichtbaren Inhalt. · **Subject Lifting** – Apples On-Device-Freistellen (VisionKit). · **Re-Seed** – Neuaufbau einer Gemini-Session mit kompaktem Textkontext statt Resumption. · **Coverage** – Anteil bereits erfasster Lagerplätze je Raum. · **Provider** – austauschbare Erkennungs-Backend-Implementierung (Gemini Live / lokal).
