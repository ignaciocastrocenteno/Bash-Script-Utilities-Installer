
#!/usr/bin/env bash
set -euo pipefail

# ======================================================================
# System Setup Script (Ubuntu/Debian)
# Installs developer tools and apps (APT/.deb/tarball) with repo setup,
# backports pinning, and secure signed-by keyrings.
# ======================================================================

log() { echo -e "[setup] $1"; }
err() { echo -e "[setup][ERROR] $1" >&2; }

require_apt() {
  if ! command -v apt >/dev/null 2>&1; then
    err "APT not found. This script supports Debian/Ubuntu only."; exit 1
  fi
}

codename() {
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -sc
  else
    . /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  fi
}

ensure_universe_multiverse() {
  if command -v add-apt-repository >/dev/null 2>&1; then
    log "Ensuring 'universe' and 'multiverse' are enabled..."
    sudo add-apt-repository -y universe || true
    sudo add-apt-repository -y multiverse || true
  fi
}

enable_backports() {
  local c=$(codename)
  local bp_list="/etc/apt/sources.list.d/backports.list"
  local bp_line="deb http://archive.ubuntu.com/ubuntu ${c}-backports main restricted universe multiverse"
  if ! grep -qs "${c}-backports" "$bp_list" 2>/dev/null; then
    log "Adding Ubuntu Backports for '${c}'..."
    echo "$bp_line" | sudo tee "$bp_list" >/dev/null
  fi
  local prefs="/etc/apt/preferences.d/99backports"
  if [[ ! -f "$prefs" ]] || ! grep -qs "Pin-Priority: 500" "$prefs"; then
    log "Setting APT pin for backports to 500."
    sudo bash -c "cat > '$prefs' <<EOF\nPackage: *\nPin: release a=${c}-backports\nPin-Priority: 500\nEOF"
  fi
}

update_indexes() { log "Refreshing package indexes..."; sudo apt update -y; }

# -------------------- Third-party repositories ------------------------
add_vscode_repo() {
  # Microsoft VS Code (APT) 
  log "Adding Microsoft VS Code repository..."
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
  cat <<EOF | sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF
}

add_brave_repo() {
  # Brave Browser official APT repo 
  log "Adding Brave Browser repository..."
  sudo install -d -m 0755 /usr/share/keyrings
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  cat <<EOF | sudo tee /etc/apt/sources.list.d/brave-browser-release.sources >/dev/null
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg
EOF
}

add_spotify_repo() {
  # Spotify official APT repo 
  log "Adding Spotify repository..."
  sudo install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc | \
    gpg --dearmor | sudo tee /usr/share/keyrings/spotify.gpg >/dev/null
  cat <<EOF | sudo tee /etc/apt/sources.list.d/spotify.sources >/dev/null
Types: deb
URIs: https://repository.spotify.com
Suites: stable
Components: non-free
Architectures: amd64
Signed-By: /usr/share/keyrings/spotify.gpg
EOF
}

add_slack_repo() {
  # Slack via Packagecloud (APT) 
  log "Adding Slack (Packagecloud) repository..."
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packagecloud.io/slacktechnologies/slack/gpgkey | \
    gpg --dearmor | sudo tee /etc/apt/keyrings/slacktechnologies_slack-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/slacktechnologies_slack-archive-keyring.gpg] https://packagecloud.io/slacktechnologies/slack/debian jessie main" | \
    sudo tee /etc/apt/sources.list.d/slack.list >/dev/null
}

add_dbeaver_repo() {
  # DBeaver CE APT repo 
  log "Adding DBeaver CE repository..."
  sudo install -d -m 0755 /etc/apt/trusted.gpg.d
  curl -fsSL https://dbeaver.io/debs/dbeaver.gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/dbeaver.gpg
  echo "deb https://dbeaver.io/debs/dbeaver-ce /" | sudo tee /etc/apt/sources.list.d/dbeaver.list >/dev/null
}

add_mozilla_firefox_repo() {
  # Mozilla official APT repository with pin to prefer it over snap 
  log "Adding Mozilla Firefox APT repository..."
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null
  cat <<EOF | sudo tee /etc/apt/sources.list.d/mozilla.sources >/dev/null
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
  # Strongly prefer Mozilla packages
  echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000" | \
    sudo tee /etc/apt/preferences.d/mozilla >/dev/null
}

add_mysql_oracle_repo() {
  # Oracle MySQL APT config (for Workbench Community) 
  log "Adding Oracle MySQL APT config (for Workbench)..."
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  # version may change; user can update later
  curl -fsSLO https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb || true
  if [[ -f mysql-apt-config_0.8.34-1_all.deb ]]; then
    sudo apt install -y ./mysql-apt-config_0.8.34-1_all.deb || true
  else
    log "MySQL APT config download skipped (version mismatch). You can install manually later."
  fi
  popd >/dev/null
}

add_mssql_repo() {
  # Microsoft SQL Server repo (supported on 22.04; 24.04 preview / workaround) 
  log "Adding Microsoft SQL Server repository..."
  sudo install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
    sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
  local c=$(codename)
  if [[ "$c" == "noble" ]]; then
    # Preview or 22.04 repo fallback
    curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list | \
      sudo tee /etc/apt/sources.list.d/mssql-server-2022.list >/dev/null || true
  else
    curl -fsSL "https://packages.microsoft.com/config/ubuntu/${c}/mssql-server-2022.list" | \
      sudo tee /etc/apt/sources.list.d/mssql-server-2022.list >/dev/null || true
  fi
}

add_mongodb_repo() {
  # MongoDB official APT repo (example: 8.0 on noble) 
  log "Adding MongoDB repository..."
  sudo install -d -m 0755 /usr/share/keyrings
  local c=$(codename)
  local ver="8.0"
  curl -fsSL https://www.mongodb.org/static/pgp/server-${ver}.asc | \
    sudo gpg -o /usr/share/keyrings/mongodb-server-${ver}.gpg --dearmor
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${ver}.gpg ] https://repo.mongodb.org/apt/ubuntu ${c}/mongodb-org/${ver} multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-org-${ver}.list >/dev/null
}

add_pg_pgdg_repo_optional() {
  # PostgreSQL PGDG repo (optional; call only if needed) 
  log "Adding PostgreSQL PGDG repository (optional)..."
  sudo apt install -y postgresql-common
  sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y || true
}

add_docker_repo() {
  # Docker APT repo (for Docker Desktop dependencies) 
  log "Adding Docker APT repository..."
  sudo install -d -m 0755 /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(codename) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
}

add_antigravity_repo() {
  # Google Antigravity IDE official APT repo (.deb) 
  log "Adding Google Antigravity repository..."
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
  echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
    sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
}

add_tor_repo() {
  # Tor Project official APT repo (optional) 
  log "Adding Tor Project repository (optional)..."
  sudo install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | \
    gpg --dearmor | sudo tee /usr/share/keyrings/deb.torproject.org-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/deb.torproject.org-keyring.gpg] https://deb.torproject.org/torproject.org $(codename) main" | \
    sudo tee /etc/apt/sources.list.d/tor-project.list >/dev/null
}

# ----------------------- Binary/tarball installs ----------------------
install_intellij_tarball() {
  # IntelliJ IDEA Community tarball install to /opt + desktop entry 
  log "Installing IntelliJ IDEA (Community) from tarball..."
  local url="https://download.jetbrains.com/product?code=IIC&release.type=release&platform=linux"
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  curl -fsSL -o idea.tar.gz "$url"
  sudo mkdir -p /opt/idea
  sudo tar -xzf idea.tar.gz --strip-components=1 -C /opt/idea
  cat <<EOF | sudo tee /usr/share/applications/intellij-idea-community.desktop >/dev/null
[Desktop Entry]
Type=Application
Name=IntelliJ IDEA Community
Icon=/opt/idea/bin/idea.png
Exec="/opt/idea/bin/idea.sh" %f
Categories=Development;IDE;
EOF
  sudo update-desktop-database || true
  popd >/dev/null
}

install_postman_tarball() {
  # Postman tarball to /opt with desktop entry 
  log "Installing Postman (tarball) to /opt..."
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  curl -fsSL -o postman.tar.gz https://dl.pstmn.io/download/latest/linux64
  sudo tar -xzf postman.tar.gz -C /opt
  sudo ln -sf /opt/Postman/Postman /usr/local/bin/postman
  cat <<EOF | sudo tee /usr/share/applications/postman.desktop >/dev/null
[Desktop Entry]
Type=Application
Name=Postman
Icon=/opt/Postman/app/resources/app/assets/icon.png
Exec=/opt/Postman/Postman
Categories=Development;
EOF
  sudo update-desktop-database || true
  popd >/dev/null
}

install_discord_deb() {
  # Discord official .deb download/install 
  log "Installing Discord (.deb)..."
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  curl -fsSL -o discord.deb "https://discord.com/api/download?platform=linux&format=deb"
  sudo apt install -y ./discord.deb
  popd >/dev/null
}

install_docker_desktop_deb() {
  # Docker Desktop .deb install (requires docker repo for dependencies) 
  log "Installing Docker Desktop (.deb)..."
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  curl -fsSL -o docker-desktop.deb "https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
  sudo apt install -y ./docker-desktop.deb || true
  popd >/dev/null
}

install_mongodb_compass_deb() {
  # MongoDB Compass .deb install 
  log "Installing MongoDB Compass (.deb)..."
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  curl -fsSL -o mongodb-compass.deb "https://downloads.mongodb.com/compass/mongodb-compass_amd64.deb" || true
  if [[ -f mongodb-compass.deb ]]; then
    sudo apt install -y ./mongodb-compass.deb || true
  else
    log "Compass download URL may have changed; please install manually from MongoDB site."
  fi
  popd >/dev/null
}

install_master_pdf_editor_deb() {
  # Master PDF Editor .deb install from Code Industry (version placeholder) 
  log "Installing Master PDF Editor (.deb)..."
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  local deb_url="https://code-industry.net/public/master-pdf-editor-5.9.10-qt5.x86_64.deb"
  curl -fsSLO "$deb_url" || true
  if ls master-pdf-editor-*.deb >/dev/null 2>&1; then
    sudo apt install -y ./master-pdf-editor-*.deb || true
  else
    log "Master PDF Editor download skipped (version mismatch)."
  fi
  popd >/dev/null
}

install_burp_suite() {
  # Burp Suite Community installer .sh (PortSwigger) 
  log "Installing Burp Suite Community..."
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  curl -fsSL -o burp.sh "https://portswigger.net/burp/releases/download?product=community&platform=linux&type=Installer"
  chmod +x burp.sh || true
  sudo ./burp.sh || true
  popd >/dev/null
}

install_metasploit() {
  # Rapid7 Nightly installer script (msfinstall) 
  log "Installing Metasploit Framework (Rapid7 script)..."
  local tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
  chmod +x msfinstall
  sudo ./msfinstall || true
  popd >/dev/null
}

install_uv_and_pip() {
  # python3-pip via APT and uv via Astral install script 
  log "Installing python3-pip and uv..."
  sudo apt install -y python3-pip
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

install_node_express() {
  # Node.js & npm (APT) and express-generator globally via npm
  log "Installing Node.js, npm, and express-generator..."
  sudo apt install -y nodejs npm
  sudo npm install -g express-generator
}

install_java_jdks() {
  # Install three JDKs (8, 11, 25) available on Ubuntu 22.04/24.04
  # Reference: Ubuntu Java availability; openjdk-25 in 24.04 repositories. 
  log "Installing OpenJDK 8, 11, and 25..."
  sudo apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-25-jdk
}

install_mysql_stack() {
  log "Installing MySQL Server & Workbench..."
  sudo apt install -y mysql-server
  sudo apt update -y
  sudo apt install -y mysql-workbench-community || true
}

install_postgresql() {
  log "Installing PostgreSQL server..."
  sudo apt install -y postgresql
}

install_mssql_express() {
  log "Installing Microsoft SQL Server (package)..."
  sudo apt update -y
  sudo apt install -y mssql-server || true
}

install_mongodb_server() {
  log "Installing MongoDB Server (mongodb-org)..."
  sudo apt update -y
  sudo apt install -y mongodb-org
}

install_firefox_deb() {
  log "Installing Firefox (.deb from Mozilla repo)..."
  sudo apt update -y
  sudo apt install -y firefox
}

install_wine() {
  log "Setting up Wine (enable i386, install wine64/wine32)..."
  sudo dpkg --add-architecture i386 || true
  sudo apt update -y
  sudo apt install -y wine64 wine32
}

install_rar_unrar() {
  log "Installing RAR/UnRAR..."
  sudo apt install -y rar unrar
}

install_misc_apt() {
  log "Installing APT packages..."
  sudo apt install -y git gcc neofetch vlc \
    libreoffice libreoffice-writer libreoffice-calc libreoffice-impress \
    thunderbird putty qbittorrent openssh-client lftp telnet john nmap flameshot \
    dbeaver-ce spotify-client brave-browser torbrowser-launcher mc evince code antigravity
}

# ------------------------------ Main ----------------------------------
main() {
  require_apt
  ensure_universe_multiverse
  enable_backports

  add_vscode_repo
  add_brave_repo
  add_spotify_repo
  add_slack_repo
  add_dbeaver_repo
  add_mozilla_firefox_repo
  add_mysql_oracle_repo
  add_mssql_repo
  add_mongodb_repo
  # Optional PGDG: uncomment next line to enable
  # add_pg_pgdg_repo_optional
  add_docker_repo
  add_antigravity_repo
  add_tor_repo

  update_indexes

  install_java_jdks
  install_misc_apt
  install_uv_and_pip
  install_node_express
  install_intellij_tarball
  install_postman_tarball
  install_discord_deb
  install_docker_desktop_deb
  install_mongodb_compass_deb
  install_master_pdf_editor_deb
  install_burp_suite
  install_metasploit

  install_mysql_stack
  install_postgresql
  install_mssql_express
  install_mongodb_server
  install_firefox_deb
  install_wine
  install_rar_unrar

  log "All requested components processed. Some installers (Burp, Docker Desktop, MSSQL setup) require interactive steps or manual confirmation."
  log "Launch apps: IntelliJ (/opt/idea), Postman ('postman'), VS Code ('code'), Brave ('brave-browser'), Slack ('slack-desktop'), Discord ('discord'), Docker Desktop, DBeaver ('dbeaver'), Spotify ('spotify'), Tor ('torbrowser-launcher'), MC ('mc')."
  log "Switch Java versions with: sudo update-alternatives --config java"
}

main "$@"
