# Schnellreferenz: MongoDB DevCore für Raspberry Pi bauen

## GitHub Actions (Empfohlen)

### Workflow manuell starten
1. Gehe zu GitHub Repository → Actions
2. Wähle "Build aarch64 DevCore for Raspberry Pi"
3. Klicke "Run workflow" → Branch: r8.2.2
4. Starte den Workflow

### Mit Tag auslösen
```bash
git checkout r8.2.2
git tag r8.2.2-build1
git push origin r8.2.2-build1
```

## Lokaler Build auf Raspberry Pi

### Einmalige Einrichtung
```bash
# Abhängigkeiten installieren
sudo apt-get update && sudo apt-get install -y \
    build-essential python3 python3-pip git \
    libcurl4-openssl-dev liblzma-dev

# Repository klonen
git clone https://github.com/zandercodes/mongo.git
cd mongo && git checkout r8.2.2

# Bazel installieren
python3 buildscripts/install_bazel.py
export PATH=~/.local/bin:$PATH
```

### Build-Konfiguration
```bash
# Raspberry Pi Flags erstellen
cat > .bazelrc.raspberrypi << 'EOF'
build --copt=-march=armv8-a+crc
build --copt=-moutline-atomics
build --copt=-mtune=cortex-a72
EOF
```

### Bauen
```bash
# Optimierter Build (dauert 6-12 Stunden)
bazel build \
    --config=opt \
    --//bazel/config:compiler_type=gcc \
    --//bazel/config:linkstatic=True \
    --bazelrc=.bazelrc.raspberrypi \
    archive-devcore

# Ergebnis
ls -lh bazel-bin/archive-devcore.tar.gz
```

## Cross-Compilation mit Docker

### Einmalige Einrichtung
```bash
# Docker und QEMU installieren
curl -fsSL https://get.docker.com | sudo sh
sudo apt-get install -y qemu-user-static
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Repository klonen
git clone https://github.com/zandercodes/mongo.git
cd mongo && git checkout r8.2.2
```

### Build starten
```bash
docker run --rm --platform linux/arm64 \
  -v $PWD:/workspace -w /workspace \
  ubuntu:22.04 bash -c '
    apt-get update && apt-get install -y \
      build-essential python3 python3-pip git \
      libcurl4-openssl-dev liblzma-dev wget curl
    python3 /workspace/buildscripts/install_bazel.py
    export PATH=~/.local/bin:$PATH
    cat > .bazelrc.raspberrypi << EOF
build --copt=-march=armv8-a+crc
build --copt=-moutline-atomics
build --copt=-mtune=cortex-a72
EOF
    bazel build --config=opt \
      --//bazel/config:compiler_type=gcc \
      --//bazel/config:linkstatic=True \
      --bazelrc=.bazelrc.raspberrypi \
      archive-devcore
    mkdir -p artifacts
    cp bazel-bin/archive-devcore.tar.gz \
       artifacts/mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz
  '
```

### Ergebnis
```bash
ls -lh artifacts/mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz
```

## Installation

### Download von GitHub Release
```bash
# Release herunterladen
wget https://github.com/zandercodes/mongo/releases/download/r8.2.2/mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz

# Entpacken
tar -xzf mongodb-devcore-r8.2.2-aarch64-raspberrypi.tar.gz
cd mongodb-devcore-r8.2.2-aarch64-raspberrypi

# Testen
./bin/mongod --version
```

### MongoDB starten
```bash
# Datenverzeichnis erstellen
sudo mkdir -p /data/db
sudo chown $USER:$USER /data/db

# Server starten
./bin/mongod --dbpath /data/db
```

## Fehlerbehebung

### Wenig RAM auf Raspberry Pi
```bash
# Swap erhöhen
sudo dphys-swapfile swapoff
echo "CONF_SWAPSIZE=8192" | sudo tee -a /etc/dphys-swapfile
sudo dphys-swapfile setup && sudo dphys-swapfile swapon

# Build mit weniger Jobs
bazel build --jobs=2 --local_ram_resources=2048 ...
```

### Bazel Installation fehlgeschlagen
```bash
# Manuelle Bazelisk Installation
wget https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-arm64
chmod +x bazelisk-linux-arm64
sudo mv bazelisk-linux-arm64 /usr/local/bin/bazel
```

## Compiler-Flags Erklärung

| Flag | Bedeutung |
|------|-----------|
| `-march=armv8-a+crc` | ARMv8-A mit CRC32 Erweiterungen |
| `-moutline-atomics` | Optimierte atomare Operationen |
| `-mtune=cortex-a72` | Optimiert für Raspberry Pi 4/5 CPU |

## Build-Zeiten (ungefähr)

| Methode | Zeit |
|---------|------|
| Raspberry Pi 4 (8GB) | 6-12 Stunden |
| Docker Cross-Compile (16-Core x86_64) | 2-4 Stunden |
| GitHub Actions | 2-3 Stunden |

## Weitere Dokumentation

- Detaillierte Anleitung: [docs/building-raspberrypi-aarch64.md](building-raspberrypi-aarch64.md)
- MongoDB Bauen: [docs/building.md](building.md)
- README: [README.md](../README.md)
