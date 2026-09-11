import time
import sqlite3
import datetime

# Pastikan path ini sama persis dengan yang ada di file webhook PHP
DB_NAME = "/var/www/html/store_data.db"

def proses_tambah_saldo(user_id, amount, ref_id):
    """
    Mengeksekusi penambahan saldo ke akun user (Universal).
    Bisa digunakan untuk Web, WhatsApp, atau sistem lainnya.
    """
    try:
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # 1. Kunci transaksi dengan mengubah paid -> completed
        c.execute("UPDATE transactions SET status = 'completed' WHERE ref_id = ? AND status = 'paid'", (ref_id,))
        
        # 2. Jika baris berhasil diubah (mencegah double-inject), tambahkan saldo
        if c.rowcount == 1:
            c.execute("UPDATE users SET balance = balance + ? WHERE user_id = ?", (amount, user_id))
            conn.commit()
            conn.close()
            return True
            
        conn.close()
        return False
    except Exception as e:
        print(f"❌ Error DB Tambah Saldo: {e}")
        return False

def gopay_checker_loop():
    """
    Background worker murni (tanpa bot).
    Tugasnya hanya memantau database setiap 15 detik.
    """
    print("🚀 [SISTEM GOPAY] Worker berjalan. Memantau database...")
    
    while True:
        try:
            conn = sqlite3.connect(DB_NAME)
            c = conn.cursor()
            
            # --- A. PROSES TRANSAKSI MASUK ---
            # Mencari data yang statusnya sudah diubah jadi 'paid' oleh Webhook Nginx
            c.execute("SELECT ref_id, user_id, amount FROM transactions WHERE status = 'paid' AND source = 'GOPAY'")
            paid_trx = c.fetchall()
            
            for trx in paid_trx:
                ref_id = trx[0]
                user_id = trx[1]
                amount = trx[2]
                
                # Eksekusi penambahan saldo
                if proses_tambah_saldo(user_id, amount, ref_id):
                    print(f"✅ [SUKSES] Rp {amount:,} masuk ke User ID {user_id} (Ref: {ref_id})")
                    
                    # ========================================================
                    # 🔔 AREA CUSTOM NOTIFIKASI
                    # Panggil fungsi API eksternal Anda di sini.
                    # Contoh WhatsApp:
                    # kirim_wa(user_id, f"Saldo Rp{amount} berhasil ditambahkan.")
                    # Contoh Website (Node.js/Socket):
                    # emit_socket_sukses(user_id, amount)
                    # ========================================================

            # --- B. PEMBERSIHAN TRANSAKSI KADALUARSA ---
            # Mengubah transaksi 'pending' yang usianya lebih dari 30 menit menjadi 'expired'
            waktu_batas = (datetime.datetime.now() - datetime.timedelta(minutes=30)).strftime("%Y-%m-%d %H:%M:%S")
            c.execute("UPDATE transactions SET status = 'expired' WHERE status = 'pending' AND source = 'GOPAY' AND date < ?", (waktu_batas,))
            
            if c.rowcount > 0:
                print(f"⚠️ [EXPIRED] {c.rowcount} tagihan otomatis dibatalkan karena melewati batas 30 menit.")
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            print(f"❌ Error Pengecekan GoPay: {e}")
            
        # Jeda 15 detik agar tidak membebani CPU VPS
        time.sleep(15)

if __name__ == "__main__":
    # Menjalankan loop secara langsung jika file ini dieksekusi via terminal (python gopay_worker.py)
    gopay_checker_loop()
