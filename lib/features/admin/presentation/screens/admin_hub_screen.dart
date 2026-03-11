import 'package:flutter/material.dart';

import '../../../../core/utils/layout.dart';
import '../../../../core/widgets/glass_widgets.dart';

class AdminHubScreen extends StatelessWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = screenBottomPadding(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding.toDouble()),
      children: const [
        Text(
          'Admin Tools',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 12),
        GlassCard(
          glow: true,
          child: ListTile(
            leading: Icon(Icons.manage_accounts_rounded),
            title: Text('User Management'),
            subtitle: Text('Manage user access and roles.'),
          ),
        ),
        SizedBox(height: 10),
        GlassCard(
          glow: true,
          child: ListTile(
            leading: Icon(Icons.business_rounded),
            title: Text('Branch Management'),
            subtitle: Text('Manage business branches and assignments.'),
          ),
        ),
      ],
    );
  }
}
