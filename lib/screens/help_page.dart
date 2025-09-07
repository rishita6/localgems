// lib/help_page.dart
import 'package:flutter/material.dart';
import 'common_widgets.dart';

class HelpPage extends StatelessWidget {
  final String uid;
  const HelpPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return DarkScaffold(
      title: 'Help & Support',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Add in-app FAQ content or open web link
            },
            child: CardTile(
              title: 'FAQs',
              subtitle:
                  'Common questions about orders, addresses, payments, and favorites.',
              trailing: 'View',
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // optionally open email or phone intent
            },
            child: CardTile(
              title: 'Contact Support',
              subtitle: 'Email: support@localgems.app\nPhone: +91-00000 00000',
              trailing: 'Reach us',
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // implement reporting flow (form + firestore doc)
            },
            child: CardTile(
              title: 'Report a Problem',
              subtitle:
                  'Report order or payment related issues and we will contact you.',
              trailing: 'Report',
            ),
          ),
        ],
      ),
    );
  }
}