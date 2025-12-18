# MongoDB DevCore für Raspberry Pi (ARM64/aarch64) erstellen

Dieses Dokument beschreibt Schritt für Schritt, wie Sie MongoDB DevCore Binaries für Raspberry Pi (ARM64/aarch64) mit den optimierten Compiler-Flags erstellen können.

## Inhalt

- [Voraussetzungen](#voraussetzungen)
- [Automatisches Erstellen mit GitHub Actions](#automatisches-erstellen-mit-github-actions)
- [Manuelles Erstellen](#manuelles-erstellen)
  - [Methode 1: Auf einem Raspberry Pi](#methode-1-auf-einem-raspberry-pi)
  - [Methode 2: Cross-Compilation auf x86_64](#methode-2-cross-compilation-auf-x86_64)
- [Installation und Verwendung](#installation-und-verwendung)
- [Fehlerbehebung](#fehlerbehebung)

## Voraussetzungen

### Hardware-Anforderungen

- **Für Raspberry Pi Build:**
  - Raspberry Pi 4 oder 5 (empfohlen: 8 GB RAM)
  - Mindestens 32 GB freier Speicherplatz (vorzugsweise auf SSD)
  - Stabile Internetverbindung

- **Für Cross-Compilation:**
  - x86_64 Linux-System
  - Mindestens 16 GB RAM
  - 30+ GB freier Speicherplatz
  - Docker installiert

### Software-Anforderungen

- Python 3.10 oder höher
- GCC 14.2 oder Clang 19.1
- Git
- Bazel (wird automatisch installiert)
- libcurl-dev
- liblzma-dev

## Automatisches Erstellen mit GitHub Actions

Die einfachste Methode ist die Verwendung der GitHub Actions CI/CD Pipeline.

### Schritt 1: GitHub Actions Workflow auslösen

Es gibt zwei Möglichkeiten, den Build-Prozess zu starten:

#### Option A: Automatischer Build bei Tag-Push

Der Workflow wird automatisch ausgelöst, wenn ein Tag mit dem Namen `r8.2.2` oder `r8.2.2-*` gepusht wird:

```bash
git checkout r8.2.2
git tag r8.2.2-build1
git push origin r8.2.2-build1
```

#### Option B: Manueller Workflow-Start

1. Gehen Sie zu Ihrem GitHub Repository
2. Klicken Sie auf "Actions"
3. Wählen Sie "Build aarch64 DevCore for Raspberry Pi"
4. Klicken Sie auf "Run workflow"
5. Wählen Sie den Branch `r8.2.2`
6. Optional: Aktivieren Sie "Create GitHub release after successful build"
7. Klicken Sie auf "Run workflow"

### Schritt 2: Build-Fortschritt überwachen

1. Gehen Sie zu "Actions" in Ihrem Repository
2. Klicken Sie auf den laufenden Workflow
3. Beobachten Sie die Build-Logs in Echtzeit

### Schritt 3: Artifacts herunterladen

Nach erfolgreichem Build:

**Wenn ein Release erstellt wurde:**
1. Gehen Sie zu "Releases" in Ihrem Repository
2. Laden Sie `mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz` herunter
3. Laden Sie die `.sha256` Datei für die Verifikation herunter

**Oder über Artifacts:**
1. Gehen Sie zum Workflow-Run
2. Scrollen Sie nach unten zu "Artifacts"
3. Laden Sie "mongodb-devcore-aarch64-raspberrypi" herunter

## Manuelles Erstellen

### Methode 1: Auf einem Raspberry Pi

Diese Methode baut MongoDB direkt auf dem Raspberry Pi.

#### Schritt 1: System vorbereiten

```bash
# System aktualisieren
sudo apt-get update
sudo apt-get upgrade -y

# Build-Abhängigkeiten installieren
sudo apt-get install -y \
    build-essential \
    python3 \
    python3-pip \
    git \
    libcurl4-openssl-dev \
    liblzma-dev \
    wget \
    curl
```

#### Schritt 2: Repository klonen

```bash
# MongoDB Repository klonen
git clone https://github.com/zandercodes/mongo.git
cd mongo

# Zum r8.2.2 Branch wechseln
git checkout r8.2.2
```

#### Schritt 3: Bazel installieren

```bash
# Bazel mit dem mitgelieferten Skript installieren
python3 buildscripts/install_bazel.py

# Bazel zum PATH hinzufügen
export PATH=~/.local/bin:$PATH

# Installation verifizieren
bazel --version
```

#### Schritt 4: Raspberry Pi spezifische Build-Konfiguration erstellen

```bash
# Erstellen Sie eine benutzerdefinierte .bazelrc für Raspberry Pi Optimierungen
cat > .bazelrc.raspberrypi << 'EOF'
# Raspberry Pi spezifische Compiler-Flags
build --copt=-march=armv8-a+crc
build --copt=-moutline-atomics
build --copt=-mtune=cortex-a72

# Optional: Weitere Optimierungen
build --copt=-O3
build --copt=-DNDEBUG
EOF
```

#### Schritt 5: MongoDB DevCore bauen

```bash
# DevCore mit Raspberry Pi Optimierungen bauen
# ACHTUNG: Dies kann mehrere Stunden dauern!
bazel build \
    --config=opt \
    --//bazel/config:compiler_type=gcc \
    --//bazel/config:linkstatic=True \
    --bazelrc=.bazelrc.raspberrypi \
    archive-devcore

# Oder für einen schnelleren Build mit weniger Optimierungen:
bazel build \
    --config=fastbuild \
    --//bazel/config:compiler_type=gcc \
    --//bazel/config:linkstatic=True \
    --bazelrc=.bazelrc.raspberrypi \
    archive-devcore
```

**Hinweis:** Der Build-Prozess kann auf einem Raspberry Pi 4 zwischen 6-12 Stunden dauern. Stellen Sie sicher, dass:
- Der Raspberry Pi ausreichend gekühlt ist
- Eine stabile Stromversorgung vorhanden ist
- Genügend Swap-Speicher konfiguriert ist (empfohlen: 8 GB)

#### Schritt 6: Swap-Speicher erhöhen (empfohlen)

```bash
# Aktuellen Swap prüfen
free -h

# Swap-Größe erhöhen (falls nötig)
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# Ändern Sie CONF_SWAPSIZE auf 8192
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

#### Schritt 7: Build-Artefakte lokalisieren

```bash
# Das erstellte Archiv finden
ls -lh bazel-bin/archive-devcore.tar.gz

# Archiv an einen gewünschten Ort kopieren
cp bazel-bin/archive-devcore.tar.gz ~/mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz

# Prüfsumme erstellen
cd ~
sha256sum mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz > mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz.sha256
```

### Methode 2: Cross-Compilation auf x86_64

Diese Methode verwendet Docker und QEMU für die Cross-Compilation auf einem leistungsstärkeren x86_64 System.

#### Schritt 1: Docker und QEMU installieren

```bash
# Docker installieren (falls noch nicht vorhanden)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Neu anmelden oder 'newgrp docker' ausführen

# QEMU für ARM64 Emulation installieren
sudo apt-get install -y qemu-user-static binfmt-support
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

#### Schritt 2: Repository klonen

```bash
git clone https://github.com/zandercodes/mongo.git
cd mongo
git checkout r8.2.2
```

#### Schritt 3: Build in Docker-Container ausführen

```bash
# ARM64 Ubuntu Container mit Build starten
docker run --rm \
  --platform linux/arm64 \
  -v $PWD:/workspace \
  -w /workspace \
  -e MONGODB_VERSION=r8.2.2 \
  ubuntu:22.04 \
  bash -c '
    set -e
    
    echo "=== System aktualisieren und Abhängigkeiten installieren ==="
    apt-get update
    apt-get install -y \
      build-essential \
      python3 \
      python3-pip \
      libcurl4-openssl-dev \
      liblzma-dev \
      git \
      wget \
      curl
    
    echo "=== Bazel installieren ==="
    python3 /workspace/buildscripts/install_bazel.py
    export PATH=~/.local/bin:$PATH
    bazel --version
    
    echo "=== Raspberry Pi Konfiguration erstellen ==="
    cat > .bazelrc.raspberrypi << EOF
# Raspberry Pi spezifische Compiler-Flags
build --copt=-march=armv8-a+crc
build --copt=-moutline-atomics
build --copt=-mtune=cortex-a72
EOF
    
    echo "=== MongoDB DevCore bauen (Dies kann 2-4 Stunden dauern) ==="
    bazel build \
      --config=opt \
      --//bazel/config:compiler_type=gcc \
      --//bazel/config:linkstatic=True \
      --bazelrc=.bazelrc.raspberrypi \
      archive-devcore
    
    echo "=== Artefakte vorbereiten ==="
    mkdir -p /workspace/artifacts
    cp bazel-bin/archive-devcore.tar.gz \
       /workspace/artifacts/mongodb-devcore-${MONGODB_VERSION}-aarch64-raspberrypi.tar.gz
    
    cd /workspace/artifacts
    sha256sum mongodb-devcore-${MONGODB_VERSION}-aarch64-raspberrypi.tar.gz \
      > mongodb-devcore-${MONGODB_VERSION}-aarch64-raspberrypi.tar.gz.sha256
    
    echo "=== Build erfolgreich abgeschlossen! ==="
    ls -lh /workspace/artifacts/
  '
```

#### Schritt 4: Build-Artefakte finden

```bash
ls -lh artifacts/
# mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz
# mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz.sha256
```

## Installation und Verwendung

### Schritt 1: Archiv auf Raspberry Pi übertragen

```bash
# Von Ihrem Build-System zum Raspberry Pi kopieren
scp mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz* pi@raspberrypi.local:~/
```

### Schritt 2: Auf dem Raspberry Pi entpacken

```bash
# Prüfsumme verifizieren
sha256sum -c mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz.sha256

# Archiv entpacken
tar -xzf mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz

# In das Verzeichnis wechseln
cd mongodb-devcore-r8.2.2-aarch64-raspberrypi
```

### Schritt 3: MongoDB konfigurieren und starten

```bash
# Datenverzeichnis erstellen
sudo mkdir -p /data/db
sudo chown -R $USER:$USER /data/db

# MongoDB Version prüfen
./bin/mongod --version

# MongoDB starten
./bin/mongod --dbpath /data/db --bind_ip 127.0.0.1

# In einem anderen Terminal: MongoDB Shell starten
./bin/mongo
```

### Schritt 4: MongoDB als Systemdienst einrichten (optional)

```bash
# Binaries nach /usr/local installieren
sudo cp -r bin/* /usr/local/bin/

# Systemd Service Datei erstellen
sudo nano /etc/systemd/system/mongod.service
```

Inhalt für `/etc/systemd/system/mongod.service`:

```ini
[Unit]
Description=MongoDB Database Server
Documentation=https://docs.mongodb.org/manual
After=network.target

[Service]
User=mongodb
Group=mongodb
Type=forking
PIDFile=/var/run/mongodb/mongod.pid
ExecStart=/usr/local/bin/mongod --config /etc/mongod.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
```

```bash
# MongoDB Benutzer erstellen
sudo useradd -r -M -s /bin/false mongodb

# Verzeichnisse erstellen
sudo mkdir -p /var/lib/mongodb /var/log/mongodb /var/run/mongodb
sudo chown -R mongodb:mongodb /var/lib/mongodb /var/log/mongodb /var/run/mongodb

# Konfigurationsdatei erstellen
sudo nano /etc/mongod.conf
```

Inhalt für `/etc/mongod.conf`:

```yaml
# mongod.conf für Raspberry Pi

# Speicherort für Datenbankdateien
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# Log-Einstellungen
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# Netzwerk-Einstellungen
net:
  port: 27017
  bindIp: 127.0.0.1

# Process Management
processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo
```

```bash
# Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable mongod
sudo systemctl start mongod
sudo systemctl status mongod
```

## Fehlerbehebung

### Problem: Build schlägt mit Speicherfehler fehl

**Lösung:**
```bash
# Swap-Speicher erhöhen
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=8192 setzen
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Build mit reduzierter Parallelität
bazel build --jobs=2 --local_ram_resources=2048 ...
```

### Problem: Bazel Installation schlägt fehl

**Lösung:**
```bash
# Manuelle Bazelisk Installation
wget https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-arm64
chmod +x bazelisk-linux-arm64
sudo mv bazelisk-linux-arm64 /usr/local/bin/bazel
```

### Problem: "Illegal instruction" beim Ausführen

**Ursache:** Binary wurde nicht mit den richtigen Flags kompiliert.

**Lösung:**
Stellen Sie sicher, dass die `.bazelrc.raspberrypi` Datei korrekt erstellt wurde und beim Build verwendet wird.

### Problem: Build dauert sehr lange

**Lösungen:**
1. Verwenden Sie `--config=fastbuild` statt `--config=opt`
2. Reduzieren Sie die Anzahl der parallelen Jobs: `--jobs=2`
3. Verwenden Sie Cross-Compilation auf einem schnelleren x86_64 System
4. Verwenden Sie die GitHub Actions Pipeline

### Problem: Docker ARM64 Emulation ist langsam

**Lösung:**
Die Emulation mit QEMU ist langsamer als nativer Build. Für bessere Performance:
- Verwenden Sie einen echten ARM64 Build-Server (z.B. AWS Graviton)
- Oder bauen Sie direkt auf dem Raspberry Pi (dauert länger, aber keine Emulation)

## Weitere Informationen

### Compiler-Flags Erklärung

- **`-march=armv8-a+crc`**: Zielt auf ARMv8-A Architektur mit CRC32-Erweiterungen ab
- **`-moutline-atomics`**: Verwendet optimierte atomare Operationen (wichtig für Multicore)
- **`-mtune=cortex-a72`**: Optimiert speziell für Cortex-A72 CPU (Raspberry Pi 4/5)

### Unterstützte Raspberry Pi Modelle

Diese Binaries funktionieren auf:
- ✅ Raspberry Pi 4 (alle Varianten)
- ✅ Raspberry Pi 5
- ✅ Raspberry Pi 400
- ⚠️ Raspberry Pi 3 (möglicherweise eingeschränkte Performance)

### Performance-Tipps

1. **Verwenden Sie SSD statt SD-Karte** für deutlich bessere I/O Performance
2. **Aktivieren Sie aktive Kühlung** für sustained Performance
3. **Verwenden Sie 8GB RAM Modell** für größere Datenbanken
4. **Konfigurieren Sie Swap** (mindestens 4GB) für Stabilität

## Support und Beiträge

Bei Problemen oder Fragen:
1. Überprüfen Sie die [MongoDB Dokumentation](https://docs.mongodb.org/)
2. Öffnen Sie ein Issue auf GitHub
3. Konsultieren Sie die [Build-Dokumentation](building.md)

## Lizenz

MongoDB ist unter der [Server Side Public License (SSPL) v1](../LICENSE-Community.txt) lizenziert.
