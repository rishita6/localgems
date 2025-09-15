// lib/addresses_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_page.dart'; // path adjusted for typical lib/screens/ layout; change if needed
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
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Add manually'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => EditAddressPage(uid: uid)));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_city),
                      title: const Text('Pick on map'),
                      onTap: () async {
                        Navigator.pop(context);
                        // open location page in "set" mode; LocationPage will create an address doc for non-sellers
                        final docId = await Navigator.push<String?>(
                          context,
                          MaterialPageRoute(builder: (_) => const LocationPage(mode: 'set')),
                        );

                        if (docId != null && docId.isNotEmpty) {
                          // fetch the created doc and open edit screen so user can set label, etc.
                          final snap = await ref.doc(docId).get();
                          final data = snap.exists ? snap.data() : null;
                          if (data != null) {
                            if (!context.mounted) return;
                            Navigator.push(context, MaterialPageRoute(builder: (_) => EditAddressPage(uid: uid, docId: docId, data: data)));
                          } else {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address saved from map')));
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ],
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFEF3167)));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const EmptyState(message: 'No addresses saved.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final docSnap = docs[i];
              final d = docSnap.data();

              final label = (d['label'] ?? 'Address').toString();
              final fullAddress = (d['fullAddress'] ??
                       d['address'] ??
                       d['line1'] ??
                       d['line'] ??
                       d['full_address'] ??
                       '').toString();
              final subtitleText = fullAddress.isNotEmpty ? fullAddress : 'Tap to edit address';

              return Dismissible(
                key: ValueKey(docSnap.id),
                background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: const Color(0xFFEF3167), child: const Icon(Icons.delete, color: Colors.white)),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete address'),
                      content: const Text('Are you sure you want to delete this saved address?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await docSnap.reference.delete();
                    return true;
                  }
                  return false;
                },
                child: CardTile(
                  title: label,
                  subtitle: subtitleText,
                  trailing: 'Edit',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditAddressPage(uid: uid, docId: docSnap.id, data: d))),
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
  late final TextEditingController fullAddressController =
      TextEditingController(text: widget.data?['fullAddress'] ?? widget.data?['address'] ?? widget.data?['line1'] ?? '');
  bool saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => saving = true);

    final Map<String, dynamic> dataToSave = {
      'label': labelController.text.trim(),
      'fullAddress': fullAddressController.text.trim(),
      'address': fullAddressController.text.trim(),
      'createdAt': widget.docId == null ? FieldValue.serverTimestamp() : widget.data?['createdAt'] ?? FieldValue.serverTimestamp(),
    };

    if (widget.data != null) {
      if (widget.data!['lat'] != null) dataToSave['lat'] = widget.data!['lat'];
      if (widget.data!['lng'] != null) dataToSave['lng'] = widget.data!['lng'];
    }

    final ref = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('addresses');
    try {
      if (widget.docId == null) {
        await ref.add(dataToSave);
      } else {
        await ref.doc(widget.docId!).set(dataToSave, SetOptions(merge: true));
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save address')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickOnMap() async {
    // If editing existing address -> ask LocationPage to update that doc
    if (widget.docId != null) {
      final targetPath = 'users/${widget.uid}/addresses/${widget.docId}';
      final result = await Navigator.push<bool?>(
        context,
        MaterialPageRoute(builder: (_) => LocationPage(mode: 'set', targetAddressDocPath: targetPath)),
      );

      if (result == true) {
        final ref = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('addresses').doc(widget.docId);
        final snap = await ref.get();
        final newData = snap.exists ? snap.data() : null;
        if (newData != null) {
          if (!mounted) return;
          setState(() {
            fullAddressController.text = (newData['fullAddress'] ?? newData['address'] ?? '').toString();
            labelController.text = (newData['label'] ?? labelController.text).toString();
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address updated from map')));
        }
      }
      return;
    }

    // Adding new address: LocationPage will create doc and return its id
    final docId = await Navigator.push<String?>(context, MaterialPageRoute(builder: (_) => const LocationPage(mode: 'set')));
    if (docId != null && docId.isNotEmpty) {
      final ref = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('addresses').doc(docId);
      final snap = await ref.get();
      final data = snap.exists ? snap.data() : null;
      if (data != null) {
        if (!mounted) return;
        Navigator.pop(context); // close current Add screen
        Navigator.push(context, MaterialPageRoute(builder: (_) => EditAddressPage(uid: widget.uid, docId: docId, data: data)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.docId != null;
    return DarkScaffold(
      title: isEditing ? 'Edit Address' : 'Add Address',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              Input(label: 'Label (Home/Work/Other)', controller: labelController),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: fullAddressController,
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    labelStyle: const TextStyle(color: Color(0xFFEF3167), fontWeight: FontWeight.w700),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFD0E3FF)), borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFEF3167)), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF3167)),
                      onPressed: saving ? null : _save,
                      child: saving ? const CircularProgressIndicator(color: Colors.white) : Text(isEditing ? 'Update' : 'Save', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!isEditing)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.location_city),
                      label: const Text('Pick on map', style: const TextStyle(color: Colors.white)),
    
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF3167)),
                      onPressed: _pickOnMap,
                    ),
                  if (isEditing)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.location_city),
                      label: const Text('Pick on map',style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF3167)),
                      onPressed: _pickOnMap,
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
