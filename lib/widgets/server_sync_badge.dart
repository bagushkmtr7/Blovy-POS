import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/realtime_sync_service.dart';

class ServerSyncBadge extends StatelessWidget {
  final AppThemeConfig tema;
  const ServerSyncBadge({super.key, required this.tema});

  void _bukaDialogServer(BuildContext context) {
    final sync = RealtimeSyncService.instance;
    final ctrl = TextEditingController(text: sync.serverUrl);
    String? infoTest;
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text(
            'Server SQLite Pusat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Jika APK & Termux di 1 HP yang sama, isi: http://127.0.0.1:8085\nJika beda HP dalam 1 Wi-Fi, isi IP HP Server (misal http://192.168.1.10:8085).',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'URL Server SQLite',
                    hintText: 'http://127.0.0.1:8085',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: sync.pendingCount,
                  builder: (_, pending, __) => Text(
                    pending != 0
                        ? 'Antrean offline tertunda: $pending data belum terkirim'
                        : 'Semua data sudah tersinkron ke pusat.',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
                if (infoTest != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    infoTest!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: sync.isOnline.value ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            OutlinedButton(
              onPressed: loading
                  ? null
                  : () async {
                      setDlg(() {
                        loading = true;
                        infoTest = 'Menghubungkan & mengirim antrean...';
                      });
                      await sync.setServerUrl(ctrl.text);
                      await sync.flushQueue();
                      setDlg(() {
                        loading = false;
                        infoTest = sync.isOnline.value
                            ? 'Berhasil terhubung & sinkron ke SQLite!'
                            : 'Gagal terhubung ke ${sync.serverUrl}. Pastikan server.py aktif.';
                      });
                    },
              child: Text(loading ? 'Menyinkronkan...' : 'Simpan & Sinkronkan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = RealtimeSyncService.instance;
    return ValueListenableBuilder(
      valueListenable: sync.isOnline,
      builder: (context, online, _) {
        return ValueListenableBuilder(
          valueListenable: sync.pendingCount,
          builder: (context, pending, _) {
            final statusColor = online ? Colors.green.shade700 : Colors.orange.shade800;
            final label = online
                ? 'ONLINE - Realtime SQLite Terhubung'
                : (pending != 0
                    ? 'OFFLINE - $pending antrean tertunda (Ketuk kirim)'
                    : 'OFFLINE - Mode Lokal (Ketuk atur server)');
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _bukaDialogServer(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    Icon(
                      online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                    Icon(Icons.tune_rounded, size: 15, color: statusColor),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
