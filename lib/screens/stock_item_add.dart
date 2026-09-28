import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/stock_l10n.dart';
import '../l10n/strings.dart';
import '../routes.dart';
import '../services/stock_service.dart';
import '../theme.dart';
import '../widgets/hb_chrome.dart';

/// Add / edit a stock item. Edit mode when [itemId] is supplied
/// (also accepted via route arguments `{'itemId': id}`).
/// Route: [Routes.stockItemAdd].
class StockItemAddScreen extends StatefulWidget {
  static const routeName = Routes.stockItemAdd;

  final String? itemId;

  const StockItemAddScreen({super.key, this.itemId});

  @override
  State<StockItemAddScreen> createState() => _StockItemAddScreenState();
}

class _StockItemAddScreenState extends State<StockItemAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _buyCtrl = TextEditingController();
  final _sellCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _lowCtrl = TextEditingController();
  final _customUnitCtrl = TextEditingController();

  static const _units = ['pcs', 'kg', 'ltr', 'box', 'mtr'];
  String _unit = 'pcs';
  bool _customUnit = false;
  String _photoPath = '';
  StockItem? _editing;
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _buyCtrl.dispose();
    _sellCtrl.dispose();
    _barcodeCtrl.dispose();
    _lowCtrl.dispose();
    _customUnitCtrl.dispose();
    super.dispose();
  }

  void _loadArgs(BuildContext context) {
    if (_loaded) return;
    _loaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final id = widget.itemId ??
        (args is Map ? args['itemId'] as String? : null);
    if (id != null) {
      _editing = HiveService.stockItems.get(id);
      final item = _editing;
      if (item != null) {
        _nameCtrl.text = item.name;
        _buyCtrl.text = _num(item.buyPrice);
        _sellCtrl.text = _num(item.sellPrice);
        _barcodeCtrl.text = item.barcode;
        _lowCtrl.text =
            item.lowStockAt == null ? '' : _num(item.lowStockAt!);
        _photoPath = item.photoPath;
        if (_units.contains(item.unit)) {
          _unit = item.unit;
        } else {
          _customUnit = true;
          _customUnitCtrl.text = item.unit;
        }
      }
    }
  }

  String _num(double v) =>
      v == v.truncateToDouble() ? v.truncate().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    _loadArgs(context);
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          appBar: HBAppBar(
              title: _editing == null
                  ? stockTr('stock.addItem')
                  : stockTr('stock.editItem')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _photoTile(context, isDark),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: stockTr('stock.itemName'),
                    hintText: stockTr('stock.itemNameHint'),
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? stockTr('stock.nameRequired')
                      : null,
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: stockTr('stock.unit'),
                    prefixIcon: const Icon(Icons.straighten_outlined),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _customUnit ? 'custom' : _unit,
                      isExpanded: true,
                      items: [
                        for (final u in _units)
                          DropdownMenuItem(
                              value: u,
                              child: Text(stockTr('stock.units.$u'))),
                        DropdownMenuItem(
                            value: 'custom',
                            child: Text(stockTr('stock.units.custom'))),
                      ],
                      onChanged: (v) => setState(() {
                        if (v == 'custom') {
                          _customUnit = true;
                        } else {
                          _customUnit = false;
                          _unit = v ?? 'pcs';
                        }
                      }),
                    ),
                  ),
                ),
                if (_customUnit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customUnitCtrl,
                    decoration: InputDecoration(
                      labelText: stockTr('stock.customUnit'),
                      hintText: stockTr('stock.customUnitHint'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => _customUnit &&
                            (v == null || v.trim().isEmpty)
                        ? stockTr('stock.nameRequired')
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                          labelText: stockTr('stock.buyPrice'),
                          prefixIcon:
                              const Icon(Icons.shopping_cart_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sellCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                          labelText: stockTr('stock.sellPrice'),
                          prefixIcon: const Icon(Icons.sell_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcodeCtrl,
                  decoration: InputDecoration(
                    labelText: stockTr('stock.barcode'),
                    prefixIcon: const Icon(Icons.qr_code_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lowCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: stockTr('stock.lowStockAt'),
                    hintText: stockTr('stock.lowStockHint'),
                    prefixIcon:
                        const Icon(Icons.warning_amber_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: Text(stockTr('stock.save'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HBColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  /// [INFERRED] Photo picker tile: gallery image, tap to change.
  Widget _photoTile(BuildContext context, bool isDark) {
    final hasPhoto =
        _photoPath.isNotEmpty && File(_photoPath).existsSync();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickPhoto,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? HBColors.cardDark : HBColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isDark ? HBColors.hairlineDark : HBColors.hairline),
          image: hasPhoto
              ? DecorationImage(
                  image: FileImage(File(_photoPath)), fit: BoxFit.cover)
              : null,
        ),
        child: hasPhoto
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      size: 32, color: HBColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    stockTr('stock.tapToAddPhoto'),
                    style: const TextStyle(
                        color: HBColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _photoPath = picked.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final unit = _customUnit ? _customUnitCtrl.text.trim() : _unit;
    final buy = double.tryParse(_buyCtrl.text.trim()) ?? 0;
    final sell = double.tryParse(_sellCtrl.text.trim()) ?? 0;
    final lowText = _lowCtrl.text.trim();
    final low = lowText.isEmpty ? null : double.tryParse(lowText);

    final editing = _editing;
    if (editing == null) {
      await StockService.addItem(
        name: _nameCtrl.text,
        unit: unit,
        buyPrice: buy,
        sellPrice: sell,
        barcode: _barcodeCtrl.text,
        photoPath: _photoPath,
        lowStockAt: low,
      );
    } else {
      editing.name = _nameCtrl.text.trim();
      editing.unit = unit;
      editing.buyPrice = buy;
      editing.sellPrice = sell;
      editing.barcode = _barcodeCtrl.text.trim();
      editing.photoPath = _photoPath;
      editing.lowStockAt = low;
      await StockService.updateItem(editing);
    }
    if (!mounted) return;
    HBToast.show(context,
        message: stockTr('stock.saved'), icon: Icons.check);
    Navigator.of(context).pop(true);
  }
}
