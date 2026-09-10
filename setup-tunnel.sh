#!/bin/bash
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

clear
echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}  AUTO SETUP CLOUDFLARE TUNNEL + PM2 v2.0    ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# === TAHAP 0: TUTORIAL DAPAT TOKEN ===
echo -e "${YELLOW}[TAHAP 1] CARA DAPAT TOKEN DARI CLOUDFLARE${NC}"
echo "1. Buka: https://dash.cloudflare.com"
echo "2. Menu: Zero Trust > Access > Tunnels"
echo "3. Klik: Create a tunnel > Name: ptero-app > Next"
echo "4. Pilih: Docker > Copy TOKEN yg panjang itu"
echo "5. Klik Next > Next > Save Tunnel. JANGAN add hostname dulu"
echo ""
read -p "Kalau sudah dapat TOKEN, tekan ENTER untuk lanjut..."
echo ""

# === TAHAP 1: INPUT DARI USER ===
echo -e "${YELLOW}[TAHAP 2] INPUT DATA${NC}"
read -p "1. Paste TOKEN TUNNEL dari Cloudflare: " TOKEN
if [ -z "$TOKEN" ]; then echo -e "${RED}Token wajib diisi!${NC}"; exit 1; fi

read -p "2. Masukkan DOMAIN kamu contoh: www.domain.com: " DOMAIN
if [ -z "$DOMAIN" ]; then echo -e "${RED}Domain wajib diisi!${NC}"; exit 1; fi

DETECTED_PORT=${SERVER_PORT}
read -p "3. Masukkan PORT APP di kode kamu [Default: $DETECTED_PORT]: " APP_PORT
APP_PORT=${APP_PORT:-$DETECTED_PORT}

read -p "4. Masukkan FILE UTAMA APP contoh: index.js / bot-whatsapp/index.js: " APP_FILE
if [ -z "$APP_FILE" ]; then echo -e "${RED}File wajib diisi!${NC}"; exit 1; fi

if [ ! -f "$APP_FILE" ]; then
    echo -e "${RED}ERROR: File $APP_FILE tidak ditemukan!${NC}"
    exit 1
fi

echo ""
# === TAHAP 2: INSTALL ===
echo -e "${YELLOW}[TAHAP 3] INSTALL DEPENDENSI & CLOUDFLARED${NC}"
apt update -y > /dev/null 2>&1
apt install -y pm2 lsof wget curl > /dev/null 2>&1

if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1 || apt-get install -f -y > /dev/null 2>&1
    rm cloudflared-linux-amd64.deb
fi

# === TAHAP 3: JALANKAN APP + TUNNEL DENGAN PM2 ===
echo -e "${YELLOW}[TAHAP 4] MENJALANKAN APP + TUNNEL${NC}"
pm2 delete "app-$DOMAIN" > /dev/null 2>&1 || true
pm2 delete "tunnel-$DOMAIN" > /dev/null 2>&1 || true

echo "Menjalankan: node $APP_FILE"
pm2 start "node $APP_FILE" --name "app-$DOMAIN" --env PORT=$APP_PORT
sleep 3

if ! lsof -i :$APP_PORT > /dev/null 2>&1; then
    echo -e "${RED}[ERROR] Port $APP_PORT belum aktif!${NC}"
    echo "Fix: Pastikan di kode ada: app.listen($APP_PORT, '0.0.0.0')"
    pm2 logs "app-$DOMAIN" --lines 15
    exit 1
fi
echo -e "${GREEN}[OK] App sudah jalan di port $APP_PORT${NC}"

echo "Menjalankan: cloudflared tunnel"
pm2 start "cloudflared tunnel run --token $TOKEN" --name "tunnel-$DOMAIN"
pm2 save > /dev/null 2>&1

echo -e "${GREEN}[OK] Tunnel sudah jalan${NC}"
echo ""

# === TAHAP 4: TUTORIAL ADD HOSTNAME ===
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}  CLOUDFLARE & APP SUDAH SIAP!                ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
echo -e "${YELLOW}[TAHAP 5] LANGKAH TERAKHIR: ADD HOSTNAME DI CLOUDFLARE${NC}"
echo "Balik ke halaman Tunnel kamu di Cloudflare"
echo ""
echo "1. Klik Tunnel: ptero-app > Tab: Public Hostname"
echo "2. Klik: Add a public hostname"
echo "3. Isi seperti ini:"
echo "   -----------------------------------------"
echo "   Subdomain     : $(echo $DOMAIN | cut -d'.' -f1)" 
echo "   Domain        : $(echo $DOMAIN | cut -d'.' -f2-)"
echo "   Service Type  : HTTP"
echo "   URL           : localhost:$APP_PORT"
echo "   -----------------------------------------"
echo "4. Scroll bawah > Centang: No TLS Verify"
echo "5. Klik: Save hostname"
echo ""
echo -e "${YELLOW}Tunggu 1-2 menit lalu buka: https://$DOMAIN${NC}"
echo ""
echo "Command Penting:"
echo "pm2 list               -> Cek status app + tunnel"
echo "pm2 logs app-$DOMAIN   -> Cek error app"
echo "pm2 logs tunnel-$DOMAIN-> Cek error tunnel"
echo ""
