import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/access_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';
import '../widgets/hb_chrome.dart';

/// Business setup form. Two modes, read from route arguments:
///   {'mode': 'edit'}  — editing from the More screen; pops on save.
///   anything else      — first-run create; saves then routes to PIN creation.
///
/// The constructor stays const because `routes.dart`/`main.dart` register the
/// screen without arguments; the mode is read from [ModalRoute] settings.
class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});

  /// Route name for this screen.
  static const routeName = Routes.businessSetup;

  /// Category codes shown in the picker — an original list written for
  /// Hisab Business (not copied from any competitor's taxonomy).
  static const List<String> categoryCodes = [
    'kiryana',
    'pharmacy',
    'restaurant',
    'bakery',
    'clothing',
    'mobile',
    'services',
    'other',
  ];

  /// Localized label for a [categoryCodes] entry.
  static String categoryLabel(String code) =>
      accessTr('access.cat.$code');

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _owner = TextEditingController();
  final _address = TextEditingController();

  String _category = '';
  bool _editMode = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    _editMode = args is Map && args['mode'] == 'edit';
    if (_editMode) {
      final b = HiveService.currentBusiness;
      if (b != null) {
        _name.text = b.name;
        _phone.text = b.phone;
        _owner.text = b.ownerName;
        _address.text = b.address;
        _category = b.category;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _owner.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    await showHBSheet<void>(
      context,
      title: accessTr('access.biz.typeLabel'),
      child: SafeArea(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final code in BusinessSetupScreen.categoryCodes)
              HBChip(
                label: BusinessSetupScreen.categoryLabel(code),
                selected: _category == code,
                onTap: () {
                  setState(() => _category = code);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final existing = _editMode ? HiveService.currentBusiness : null;
      final profile = BusinessProfile(
        id: existing?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        category: _category,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        ownerName: _owner.text.trim(),
        createdAt: existing?.createdAt ?? DateTime.now(),
      );
      await HiveService.business.put(profile.id, profile);
      await HiveService.setBusinessId(profile.id);
      if (!mounted) return;
      if (_editMode) {
        HBToast.show(context, message: accessTr('access.biz.saved'));
        Navigator.of(context).pop();
      } else {
        await HiveService.setFirstRun(false);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          Routes.lock,
          arguments: const {'mode': 'create'},
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, child) => Scaffold(
        appBar: HBAppBar(
          title: _editMode
              ? accessTr('access.biz.editTitle')
              : accessTr('access.biz.setupTitle'),
          showBack: _editMode,
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(accessTr('access.biz.subtitle'),
                    style: const TextStyle(
                        fontSize: 14, color: HBColors.muted)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: _deco(accessTr('access.biz.nameHint'))
                      .copyWith(labelText: tr(context, 'form.businessName')),
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? tr(context, 'form.required')
                          : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickCategory,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _deco('')
                        .copyWith(labelText: accessTr('access.biz.typeLabel')),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _category.isEmpty
                              ? accessTr('access.biz.choose')
                              : BusinessSetupScreen.categoryLabel(_category),
                          style: TextStyle(
                              color: _category.isEmpty
                                  ? HBColors.muted
                                  : null),
                        ),
                        const Icon(Icons.arrow_drop_down,
                            color: HBColors.muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _deco(accessTr('access.biz.phoneHint'))
                      .copyWith(labelText: tr(context, 'form.phone')),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _owner,
                  textInputAction: TextInputAction.next,
                  decoration: _deco(accessTr('access.biz.ownerHint'))
                      .copyWith(labelText: tr(context, 'form.ownerName')),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _address,
                  textInputAction: TextInputAction.done,
                  minLines: 2,
                  maxLines: 3,
                  decoration: _deco(accessTr('access.biz.addressHint'))
                      .copyWith(
                          labelText: accessTr('access.biz.addressLabel')),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: HBPillButton(
                    label: tr(context, 'action.save'),
                    onPressed: _saving ? null : _save,
                    color: HBColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
