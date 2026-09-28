import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/khata_l10n.dart';
import '../l10n/strings.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';

/// Add-party form (route [Routes.partyAdd]).
///
/// Name (required), phone, address, customer/supplier kind selector, notes.
/// Saves to the parties box, then pops with a success toast.
class PartyAddScreen extends StatefulWidget {
  const PartyAddScreen({super.key});

  @override
  State<PartyAddScreen> createState() => _PartyAddScreenState();
}

class _PartyAddScreenState extends State<PartyAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _kind = 'customer';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final party = Party(
      id: const Uuid().v4(),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      kind: _kind,
      notes: _notes.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await HiveService.parties.put(party.id, party);
    if (!mounted) return;
    HBToast.show(context,
        message: khataTr('khata.partySaved'), icon: Icons.check);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) => Scaffold(
        appBar: HBAppBar(title: khataTr('khata.addParty')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                key: const Key('party_name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration:
                    InputDecoration(labelText: tr(context, 'form.name')),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? khataTr('khata.nameRequired')
                        : null,
              ),
              const SizedBox(height: 16),
              Text(khataTr('khata.partyType'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  HBChip(
                    label: khataTr('khata.customer'),
                    selected: _kind == 'customer',
                    onTap: () =>
                        setState(() => _kind = 'customer'),
                  ),
                  const SizedBox(width: 8),
                  HBChip(
                    label: khataTr('khata.supplier'),
                    selected: _kind == 'supplier',
                    onTap: () =>
                        setState(() => _kind = 'supplier'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration:
                    InputDecoration(labelText: tr(context, 'form.phone')),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                    labelText: tr(context, 'form.address')),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                    labelText: tr(context, 'form.notes')),
              ),
              const SizedBox(height: 24),
              HBPillButton(
                label: khataTr('khata.saveParty'),
                icon: Icons.check,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
