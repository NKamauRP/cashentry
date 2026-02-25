import 'package:flutter/material.dart';

import '../../features/sync/presentation/controllers/sync_controller.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

class CloudSyncStatusButton extends StatelessWidget {
  const CloudSyncStatusButton({
    super.key,
    required this.controller,
  });

  final SyncController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final (icon, color, label) = _statusVisuals();
        return GlassCard(
          borderRadius: 16,
          glow: true,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final outcome = await controller.syncNow();
            messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.isSyncing)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  (IconData, Color, String) _statusVisuals() {
    if (controller.isSyncing) {
      return (Icons.cloud_sync_rounded, AppColors.teal, 'Syncing');
    }
    if (!controller.isOnline) {
      return (Icons.cloud_off_rounded, AppColors.danger, 'Offline');
    }
    if (controller.hasPendingChanges) {
      return (Icons.cloud_upload_rounded, const Color(0xFFFFB74D), 'Pending');
    }
    return (Icons.cloud_done_rounded, AppColors.teal, 'Synced');
  }
}
