
# System Setup Script

## Introduction
This script prepares an Ubuntu/Debian workstation with a **curated set of developer tools and desktop apps** using **APT (.deb) software packages**, selected **vendor repositories**, and a few **tarball/.deb installers** for apps that are not shipped in Ubuntu by design. All of these software programs are part of my daily/weekly routine, and I decided to automate the dependencies
download process to avoid losing time, allowing me to update all the packages on my computer or
even install all my necessary dependencies easily on a new fresh Linux distro.

**What’s included (high level):**
- IDEs & editors: **IntelliJ IDEA (Community)** via tarball to `/opt` + desktop entry; **Visual Studio Code** via **Microsoft APT repo**; **Google Antigravity IDE** via official **APT**.
- SDKs & build tools: **OpenJDK 8, 11, and 25 JDKs are installed explicitly** (`openjdk-8-jdk`, `openjdk-11-jdk`, `openjdk-25-jdk`). These versions are available on **Ubuntu 22.04** and **Ubuntu 24.04** per Ubuntu’s Java availability matrix, and **OpenJDK 25** has dedicated packages in **24.04 (noble)** updates.
- Maven (`maven`), **gcc** (`gcc`), **Git** (`git`).
- Python & package managers: **python3-pip** (APT) and **uv** via Astral’s official install script (non‑containerized).
- Node.js stack: **nodejs**/**npm** (APT) + global **express-generator**.
- Databases & clients: **MySQL Server** (Ubuntu APT) + **Workbench** via Oracle’s APT; **PostgreSQL Server** (Ubuntu APT) with an **optional PGDG** repo function; **Microsoft SQL Server** via Microsoft’s repo (Express via post‑install setup); **DBeaver CE** via official APT repo; **MongoDB (mongodb-org)** via official APT + **Compass .deb**.
- Browsers & comms: **Brave** (official repo), **Firefox (.deb)** via Mozilla’s APT with pin to avoid Snap, **Slack** (Packagecloud), **Discord** (.deb).
- Docker: **Docker Desktop** via official `.deb` (Docker APT repo added for dependencies).
- Security tools: **John the Ripper**, **Nmap** (APT), **Burp Suite Community** (installer `.sh`), **Metasploit Framework** (Rapid7 installer script).
- Utilities: **qBittorrent**, **Thunderbird**, **VLC**, **Evince**, **Flameshot**, **PuTTY for Linux**, **OpenSSH client, lftp, telnet**, **RAR/UnRAR** (multiverse).
- Privacy tools: **Tor Browser** via `torbrowser-launcher` (APT); **Midnight Commander (MC)** (APT).
- Media: **Spotify** via official APT repo.

## Features
- **Secure repository setup** with per‑repo `signed-by` keyrings and **DEB822** `.sources` where applicable (Mozilla, Brave, Spotify, VS Code). citeturn8search70turn8search61turn8search97turn8search85
- **Ubuntu Backports enabled & pinned (500)** so `apt update && apt upgrade -y` can pull backported packages automatically. (Backports carry limited security guarantees—see Notes.) citeturn6search35turn6search36
- **No Flatpaks/Snaps**: everything is **APT/.deb** or vendor tarball as requested.
- **Desktop entries** for **IntelliJ IDEA** and **Postman** when installed from tarballs.
- **Optional PGDG** function for PostgreSQL; call if you prefer newer Postgres than Ubuntu’s default.

## How it works
1. **Pre‑flight**: verifies APT; enables **universe** and **multiverse** (required for various packages like `torbrowser-launcher`, `rar`, etc.).
2. **Backports setup**: writes `<codename>-backports` and pins to **500** so routine upgrades include backported packages.
3. **Repositories added**: Microsoft VS Code, Brave, Spotify, Slack (Packagecloud), DBeaver CE, Mozilla Firefox (.deb), Oracle MySQL APT, Microsoft SQL Server, MongoDB (mongodb-org), Docker, Google Antigravity, Tor Project (optional).
4. **APT installs**: bulk set including Antigravity, VS Code (`code`), Brave (`brave-browser`), Spotify, DBeaver CE, Tor Browser launcher, MC, LibreOffice apps, Thunderbird, qBittorrent, VLC, Flameshot, John, Nmap, PuTTY, SSH/FTP/Telnet, etc.
5. **Language stacks**: **python3‑pip** and **uv**; **Node.js/npm** with **express-generator** globally.
6. **Tarball/.deb installs**: IntelliJ and Postman to `/opt` with desktop entries; Discord `.deb`; Docker Desktop `.deb`; MongoDB Compass `.deb`; Master PDF Editor `.deb`; Burp Suite Community installer; Metasploit Nightly installer.
7. **Databases**: MySQL server + Workbench (Oracle repo); PostgreSQL server; MSSQL Server package (run `sudo /opt/mssql/bin/mssql-conf setup` for Express); MongoDB server (mongodb-org).
8. **Java JDKs (8/11/25)**: installed by default. You can switch active Java with:
   ```bash
   # Changing the Java JDK Version
   sudo update-alternatives --config java
   # Changing the Java Compiler version
   sudo update-alternatives --config javac

   # Verifying what JDK version is currently active
   java -version
   javac -version
   ```
   Availability of **OpenJDK 25** in **Ubuntu 24.04** is confirmed via UbuntuUpdates and pkgs.org (package `openjdk-25-jdk`). **OpenJDK 8/11** remain available on LTS releases.
9. **Wine & archive tools**: enable `i386` and install `wine64`/`wine32`; install `rar` and `unrar`.

## How to execute the code
1. **Create the Bash file**
   ```bash
   nano utilities_installer.sh
   ```
   Paste the script into the editor and save.

2. **Grant privileges**
   ```bash
   chmod +x utilities_installer.sh
   ```

3. **Run in a terminal**
   ```bash
   sudo ./utilities_installer.sh
   ```

4. **Switching between Java versions (optional)**
   ```bash
   sudo update-alternatives --config java
   sudo update-alternatives --config javac
   ```
   This lets you choose **Java 8**, **Java 11**, or **Java 25** system‑wide (for me to work
   on the different professional projects I'm currently working on.)

## Notes and limitations
- **APT/.deb only** by design: we **do not** install Flatpaks or Snaps here. Flatpak uses **bubblewrap** and **portals**; Snap uses **AppArmor/seccomp/namespaces**—excellent for isolation but out of scope for this APT‑centric workflow.
- **Backports caveat**: Ubuntu Backports do **not** have guaranteed security support; pinning to 500 means routine upgrades may pull backported packages. Adjust the pin if you prefer manual opt‑in.
- **MSSQL on Ubuntu 24.04**: Microsoft’s stable repo targets 22.04; 24.04 requires preview/workaround and additional libs. Use for dev/testing, not production, unless Microsoft publishes a stable `noble` repo.
- **Version churn**: Some vendor downloads (Master PDF Editor, Discord, Docker Desktop, MongoDB Compass) change URLs or versions. The script attempts installs but may log a message if the URL changes—download manually from the vendor if needed.
- **Firefox pinning**: We configure pinning to prefer **Mozilla’s APT** over the Snap redirect; ensure you remove the Firefox snap if you want a single install.

---

### References
- **Java availability**: Ubuntu for Developers matrix showing Java 8/11/25 on 22.04/24.04.
- **OpenJDK 25 package on 24.04**: UbuntuUpdates / pkgs.org pages.
- **VS Code APT repo**: Microsoft docs.
- **IntelliJ tarball & desktop entry**: JetBrains docs.
- **Brave repo**: Brave Linux install page.
- **Spotify repo**: Spotify Linux page.
- **Slack (Packagecloud)**: how‑to article.
- **DBeaver CE repo**: ComputingForGeeks.
- **Mozilla Firefox APT & pinning**: Mozilla Support.
- **Oracle MySQL APT & Workbench**: MySQL docs.
- **PostgreSQL PGDG**: official download page.
- **Microsoft SQL Server**: current status/workarounds.
- **MongoDB APT & Compass**: MongoDB docs and downloads.
- **Docker Desktop (Linux)**: Docker docs.
- **Astral uv install**: official docs.
- **Wine i386 enable + install**: community guides.
- **RAR/UnRAR & multiverse**: enabling repositories.
- **Burp Suite**: PortSwigger docs.
- **Metasploit**: Rapid7 installer docs.
- **Tor Browser via launcher**: Linux Genie tutorial.
- **Midnight Commander**: Ubuntu tutorials.
