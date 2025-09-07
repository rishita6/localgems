// lib/widgets/common_widgets.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Updated common widgets with blue + pink theme (pintresty / soft aesthetic)
class _LocalPalette {
  static const blueBg = Color(0xFFD0E3FF); // light blue page background
  static const pink = Color(0xFFEF3167); // vivid pink accent
  static const card = Color(0xFFFFFFFF); // card background (cream/white)
  static const textDark = Color(0xFF172032); // deep text color
  static const textSoft = Color(0xFF6B7280); // soft text
}

class DarkScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const DarkScaffold({super.key, required this.title, required this.child, this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LocalPalette.blueBg,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: _LocalPalette.pink,
        actions: actions,
        titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
      body: child,
    );
  }
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const MenuTile({super.key, required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _LocalPalette.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: _LocalPalette.pink.withOpacity(0.12), blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Row(children: [
          Icon(icon, color: _LocalPalette.pink, size: 26),
          const SizedBox(width: 15),
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _LocalPalette.textDark)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF9AA4B2)),
        ]),
      ),
    );
  }
}

class CardTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  const CardTile({super.key, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _LocalPalette.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, spreadRadius: 1)],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: _LocalPalette.textDark, fontSize: 16, fontWeight: FontWeight.w700)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle!, style: TextStyle(color: _LocalPalette.textSoft, fontSize: 13))),
            ]),
          ),
          if (trailing != null) Text(trailing!, style: TextStyle(color: _LocalPalette.pink, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class Input extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const Input({super.key, required this.label, required this.controller, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: _LocalPalette.textSoft, fontWeight: FontWeight.w700),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _LocalPalette.pink.withOpacity(0.22)), borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _LocalPalette.pink), borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({
    Key? key,
    required this.message,
    this.icon = Icons.info_outline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: _LocalPalette.textSoft),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: _LocalPalette.textSoft),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
