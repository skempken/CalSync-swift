# CalSync

Eine native macOS Menubar-App zur automatischen Synchronisation von Platzhalter-Terminen zwischen mehreren Apple-Kalendern.

## Funktionsweise

Wenn du mehrere Kalender verwendest (Arbeitgeber, Kunden, privat), möchtest du oft, dass externe Parteien deine Verfügbarkeit sehen können, ohne die Details deiner Termine preiszugeben. CalSync erstellt automatisch "Nicht verfügbar"-Platzhalter in allen anderen konfigurierten Kalendern, sobald du einen Termin in einem Kalender erstellst.

**Beispiel:** Bei 3 konfigurierten Kalendern erzeugt jeder Termin 2 Platzhalter (einen in jedem der anderen Kalender).

## Features

- **Menubar-App** – Läuft diskret in der Menubar, kein Dock-Icon
- **Automatische Synchronisation** – Konfigurierbare Intervalle (5/15/30 Min, 1/2 Std)
- **Manuelle Synchronisation** – Jederzeit per Klick oder ⌘S
- **Konfigurierbarer Platzhalter-Titel** – Standard: "Nicht verfügbar"
- **Intelligente Filterung** – Ignoriert abgelehnte, ausstehende und "Frei"-Termine
- **Verfügbarkeits-Mapping** – Übernimmt Abwesend/Tentativ-Status korrekt
- **Autostart** – Optional bei Systemanmeldung starten
- **Native Performance** – Komplett in Swift, nur 608 KB

## Systemanforderungen

- macOS 15.0 (Tahoe) oder neuer
- Apple Silicon (arm64)

## Installation

```bash
git clone https://github.com/skempken/CalSync-swift.git
cd CalSync-swift
xcodegen generate
xcodebuild -project CalSync.xcodeproj -scheme CalSync -configuration Release build
```

Die fertige App liegt dann unter:
```
~/Library/Developer/Xcode/DerivedData/CalSync-*/Build/Products/Release/CalSync.app
```

## Verwendung

### Ersteinrichtung
1. App starten
2. Kalenderzugriff erlauben (Systemaufforderung)
3. Einstellungen öffnen (⌘,)
4. Mindestens 2 Kalender auswählen
5. Optional: Sync-Intervall und Platzhalter-Titel anpassen

### Menubar-Menü
- **Jetzt synchronisieren** (⌘S) – Manuelle Sync auslösen
- **Auto-Sync** – Automatische Synchronisation ein/ausschalten
- **Einstellungen...** (⌘,) – Konfiguration öffnen
- **Beenden** (⌘Q) – App beenden

### Einstellungen

| Tab | Optionen |
|-----|----------|
| Allgemein | Platzhalter-Titel, Sync-Intervall, Tage voraus, Autostart |
| Kalender | Auswahl der zu synchronisierenden Kalender |
| Info | Version und Copyright |

## Technische Details

### Sync-Logik
- Bidirektionale Synchronisation zwischen allen Kalender-Paaren
- Erkennung von Änderungen über SHA256-Hash der Termin-Attribute
- Tracking-Marker im Notizen-Feld der Platzhalter:
  ```
  [CALSYNC:{"tid":"abc12345","src":"event-id","scal":"cal-id","hash":"...","sstart":"..."}]
  ```

### Filterregeln
Folgende Termine werden **nicht** synchronisiert:
- Eigene Platzhalter (bereits synchronisiert)
- Als "Frei" markierte Termine
- Ausstehende Einladungen (noch nicht beantwortet)
- Abgelehnte Termine

### Verfügbarkeits-Mapping
| Quell-Termin | Platzhalter |
|--------------|-------------|
| Abwesend/OOO | Abwesend |
| Tentativ | Tentativ |
| Sonstige | Gebucht |

## Projektstruktur

```
CalSync/
├── CalSyncApp.swift           # App Entry Point
├── Models/                    # Datenmodelle
├── Services/                  # Sync-Engine, EventKit, Background-Sync
├── ViewModels/                # App-State, Settings-Store
├── Views/                     # SwiftUI Views
└── Utilities/                 # Konstanten
```

## Entwicklung

### Voraussetzungen
- Xcode 16+
- xcodegen (`brew install xcodegen`)

### Build
```bash
xcodegen generate
open CalSync.xcodeproj
```

### Projektdatei regenerieren
Nach Änderungen an der Dateistruktur:
```bash
xcodegen generate
```

## Lizenz

GPL-3.0 License – siehe [LICENSE](LICENSE)

## Autor

© 2025 Sebastian Kempken
