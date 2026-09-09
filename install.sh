#!/bin/bash

# Warna output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}       INSTALLER HOKAGE PG SERVER (VPS)            ${NC}"
echo -e "${GREEN}===================================================${NC}"

# 1. Deteksi IP Publik VPS Klien
VPS_IP=$(curl -s -4 icanhazip.com)
if [ -z "$VPS_IP" ]; then
    VPS_IP=$(curl -s ifconfig.me)
fi

echo -e "IP VPS Terdeteksi : ${YELLOW}$VPS_IP${NC}"
echo ""
read -p "Masukkan Nama Client (Sesuai lisensi) : " CLIENT_NAME

# 2. Verifikasi Lisensi ke GitHub
echo -e "\n[*] Memverifikasi lisensi ke database pusat..."
URL_LISENSI="https://raw.githubusercontent.com/hokagelegend/lisensi/main/ijin"
DATA_LISENSI=$(curl -s "$URL_LISENSI")

# Cek apakah baris '## namaclient-ipvps' ada di file ijin
if echo "$DATA_LISENSI" | grep -iq "## $CLIENT_NAME-$VPS_IP"; then
    echo -e "${GREEN}[+] Lisensi Valid! Akses instalasi diizinkan.${NC}\n"
else
    echo -e "${RED}[-] INSTALASI DITOLAK: Lisensi tidak valid atau IP tidak terdaftar!${NC}"
    echo -e "Pastikan format di GitHub adalah: ${YELLOW}## $CLIENT_NAME-$VPS_IP-lifetime${NC}"
    echo -e "Hubungi Admin @HookageLegend."
    exit 1
fi

# 3. Instalasi Web Server & Dependensi (Ubuntu/Debian)
echo -e "[*] Memperbarui sistem dan menginstal Nginx + PHP..."
apt-get update -y
apt-get install -y nginx php-fpm php-curl php-json curl unzip software-properties-common

# 4. Pembuatan Direktori & File Webhook
WEB_DIR="/var/www/hokage_pg"
mkdir -p "$WEB_DIR"

echo -e "[*] Membangun file sistem PG Server..."
# Membuat file webhook_gopay.php dasar (Bisa Anda kembangkan nanti)
cat << 'EOF' > "$WEB_DIR/webhook_gopay.php"
<?php
// Menerima POST data dari Aplikasi Android Hokage PG Server
$data = file_get_contents('php://input');
if(!empty($data)) {
    file_put_contents('log_transaksi.txt', $data . PHP_EOL, FILE_APPEND);
    // Masukkan logika CURL ke Telegram Bot (kyt bot) Anda di sini
}
http_response_code(200);
echo "Webhook Hokage Aktif!";
?>
EOF

chown -R www-data:www-data "$WEB_DIR"
chmod -R 755 "$WEB_DIR"

# 5. Konfigurasi Nginx di Port 81
echo -e "[*] Mengonfigurasi Nginx di Port 81..."
cat << EOF > /etc/nginx/sites-available/hokage_pg
server {
    listen 81;
    server_name $VPS_IP;
    root $WEB_DIR;
    index webhook_gopay.php;

    location / {
        try_files \$uri \$uri/ /webhook_gopay.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock; 
    }
}
EOF

# Auto-deteksi versi PHP-FPM di VPS klien agar tidak error
PHP_SOCK=$(find /var/run/php/ -name "*.sock" | head -n 1)
if [ ! -z "$PHP_SOCK" ]; then
    sed -i "s|unix:/var/run/php/php8.1-fpm.sock;|unix:$PHP_SOCK;|g" /etc/nginx/sites-available/hokage_pg
fi

ln -sf /etc/nginx/sites-available/hokage_pg /etc/nginx/sites-enabled/
systemctl restart nginx

echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}  INSTALASI SELESAI & BERHASIL!${NC}"
echo -e "URL Webhook Anda : ${YELLOW}http://$VPS_IP:81/webhook_gopay.php${NC}"
echo -e "Silakan masukkan URL di atas ke Pengaturan API di aplikasi Android."
echo -e "${GREEN}===================================================${NC}"
