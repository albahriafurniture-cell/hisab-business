import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/staff_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_chrome.dart';

/// Add a new staff member to the staff book.
class StaffAddScreen extends StatefulWidget {
  static const routeName = Routes.staffAdd;

  const StaffAddScreen({super.key});

  @override
  State<StaffAddScreen> createState() => _StaffAddScreenState();
}

class _StaffAddScreenState extends State<StaffAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  DateTime _joined = DateTime.now();
  String _photoPath = '';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _roleCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (picked != null) setState(() => _photoPath = picked.path);
  }

  Future<void> _pickJoined() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joined,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _joined = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final salary = double.tryParse(_salaryCtrl.text.trim()) ?? 0;
    final staff = StaffMember(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      role: _roleCtrl.text.trim(),
      monthlySalary: salary < 0 ? 0 : salary,
      photoPath: _photoPath,
      joinedAt: DateTime(_joined.year, _joined.month, _joined.day),
    );
    await HiveService.staff.put(staff.id, staff);
    if (!mounted) return;
    HBToast.show(context,
        message: staffTr('staff.saved'), icon: Icons.check_circle);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: HBAppBar(title: staffTr('staff.add')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        if (_photoPath.isEmpty)
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: isDark
                                ? HBColors.primarySoftDark
                                : HBColors.primarySoft,
                            child: const Icon(Icons.person_add_alt_1,
                                size: 36, color: HBColors.primary),
                          )
                        else if (!kIsWeb && File(_photoPath).existsSync())
                          CircleAvatar(
                            radius: 44,
                            backgroundImage: FileImage(File(_photoPath)),
                          )
                        else
                          const CircleAvatar(
                              radius: 44,
                              child: Icon(Icons.person, size: 36)),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: HBColors.primary,
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(staffTr('staff.photo'),
                      style: const TextStyle(
                          fontSize: 12, color: HBColors.muted)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                      labelText: staffTr('staff.name'),
                      prefixIcon: const Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? staffTr('staff.nameRequired')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: staffTr('staff.phone'),
                      prefixIcon: const Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roleCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                      labelText: staffTr('staff.role'),
                      prefixIcon: const Icon(Icons.work_outline)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _salaryCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                      labelText: staffTr('staff.salary'),
                      prefixIcon: const Icon(Icons.payments_outlined)),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    final n = double.tryParse(t);
                    return (n == null || n < 0)
                        ? staffTr('staff.invalidAmount')
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickJoined,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: staffTr('staff.joined'),
                      prefixIcon: const Icon(Icons.event_outlined),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(_joined)),
                  ),
                ),
                const SizedBox(height: 24),
                HBPillButton(
                  label: staffTr('staff.save'),
                  icon: Icons.check,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
