// lib/addresses_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'common_widgets.dart';

class AddressesPage extends StatelessWidget {
  final String uid;
  const AddressesPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid).collection('addresses');

    return DarkScaffold(
      title: 'Saved Addresses',
      actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditAddressPage(uid: uid)))),
      ],
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.orderBy('label').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const EmptyState(message: 'No addresses saved.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              return Dismissible(
                key: ValueKey(docs[i].id),
                background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await docs[i].reference.delete();
                  return true;
                },
                child: CardTile(
                  title: (d['label'] ?? 'Address').toString(),
                  subtitle: "${d['line1'] ?? ''}, ${d['city'] ?? ''} ${d['pincode'] ?? ''}\n${d['phone'] ?? ''}",
                  trailing: 'Edit',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditAddressPage(uid: uid, docId: docs[i].id, data: d))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EditAddressPage extends StatefulWidget {
  final String uid;
  final String? docId;
  final Map<String, dynamic>? data;
  const EditAddressPage({super.key, required this.uid, this.docId, this.data});

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController labelController = TextEditingController(text: widget.data?['label'] ?? '');
  late final TextEditingController line1Controller = TextEditingController(text: widget.data?['line1'] ?? '');
  late final TextEditingController cityController = TextEditingController(text: widget.data?['city'] ?? '');
  late final TextEditingController pincodeController = TextEditingController(text: widget.data?['pincode'].toString() ??'');
  late final TextEditingController phoneController = TextEditingController(text: widget.data?['phone'] .toString() ?? '');
  bool saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => saving = true);
    final data = {
      'label': labelController.text.trim(),
      'line1': line1Controller.text.trim(),
      'city': cityController.text.trim(),
      'pincode': int.tryParse(pincodeController.text.trim()) ?? 0,
      'phone':  int.tryParse(phoneController.text.trim()) ?? 0,
    };
    final ref = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('addresses');
    if (widget.docId == null) {
      await ref.add(data);
    } else {
      await ref.doc(widget.docId!).set(data);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DarkScaffold(
      title: widget.docId == null ? 'Add Address' : 'Edit Address',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              Input(label: 'Label (Home/Work)', controller: labelController),
              Input(label: 'Address Line', controller: line1Controller),
              Input(label: 'City', controller: cityController),
              Input(label: 'Pincode', controller: pincodeController, keyboardType: TextInputType.number),
              Input(label: 'Phone', controller: phoneController, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 9, 9, 9)),
                onPressed: saving ? null : _save,
                child: saving ? const CircularProgressIndicator(color: Color.fromARGB(255, 253, 251, 251)) : const Text('Save', style: TextStyle(color: Color.fromARGB(255, 251, 251, 251))),
              )
            ],
          ),
        ),
      ),
    );
  }
}
