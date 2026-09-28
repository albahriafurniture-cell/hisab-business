import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_service.dart';
import '../data/models.dart';
import '../l10n/care_l10n.dart';
import '../theme.dart';
import '../utils/app_paths.dart';
import '../widgets/hb_chrome.dart';
import '../widgets/hb_actions.dart';
import '../widgets/hb_cards.dart';

/// Digital business card maker: 3 original templates, editable fields,
/// live preview, share as PNG. Route: [Routes.businessCard].
///
/// All three templates are drawn from scratch with plain widgets —
/// no copied artwork or ornament patterns.
class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  final _name = TextEditingController();
  final _tagline = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  int _template = 0;
  late final PageController _pages;
  late final List<GlobalKey> _cardKeys;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final b = HiveService.currentBusiness;
    _name.text = b?.name ?? '';
    _owner.text = b?.ownerName ?? '';
    _phone.text = b?.phone ?? '';
    _address.text = b?.address ?? '';
    _pages = PageController();
    _cardKeys = [GlobalKey(), GlobalKey(), GlobalKey()];
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    _owner.dispose();
    _phone.dispose();
    _address.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HBAppBar(
        title: careTr('care.cardTitle'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(careTr('care.saveCard'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(careTr('care.template'),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 210,
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _template = i),
              children: [
                RepaintBoundary(
                    key: _cardKeys[0], child: _emberCard()),
                RepaintBoundary(
                    key: _cardKeys[1], child: _midnightCard()),
                RepaintBoundary(
                    key: _cardKeys[2], child: _stripeCard()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _template == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _template == i
                      ? HBColors.primary
                      : HBColors.hairline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          HBSectionLabel(careTr('care.details')),
          const SizedBox(height: 8),
          _field(_name, careTr('care.businessName'), Icons.storefront_outlined),
          _field(_tagline, careTr('care.tagline'), Icons.tag_outlined),
          _field(_owner, careTr('care.ownerName'), Icons.person_outline),
          _field(_phone, careTr('care.phone'),
              Icons.phone_outlined,
              keyboard: TextInputType.phone),
          _field(_address, careTr('care.address'),
              Icons.location_on_outlined),
          const SizedBox(height: 16),
          HBPillButton(
            label: _sharing ? '…' : careTr('care.shareCard'),
            icon: Icons.share_outlined,
            onPressed: _sharing ? null : _sharePng,
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String get _vName => _name.text.trim().isEmpty ? '…' : _name.text.trim();
  String get _vOwner =>
      _owner.text.trim().isEmpty ? '…' : _owner.text.trim();
  String get _vPhone =>
      _phone.text.trim().isEmpty ? '…' : _phone.text.trim();
  String get _vAddress =>
      _address.text.trim().isEmpty ? '…' : _address.text.trim();
  String get _vTagline => _tagline.text.trim();

  // --- Template 1: Ember — warm orange gradient, white type -------------
  Widget _emberCard() {
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [HBColors.gradientTop, HBColors.gradientBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_vName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            if (_vTagline.isNotEmpty)
              Text(_vTagline,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
            const Spacer(),
            Container(height: 1, color: Colors.white38),
            const SizedBox(height: 10),
            _line(Icons.phone, _vPhone, Colors.white),
            const SizedBox(height: 4),
            _line(Icons.location_on, _vAddress, Colors.white),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_vOwner,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Template 2: Midnight — dark card, amber accent rail ---------------
  Widget _midnightCard() {
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: HBColors.ink,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              decoration: const BoxDecoration(
                color: HBColors.amber,
                borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_vName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    if (_vTagline.isNotEmpty)
                      Text(_vTagline,
                          style: const TextStyle(
                              color: HBColors.amber, fontSize: 13)),
                    const Spacer(),
                    _line(Icons.phone, _vPhone, HBColors.mutedDark),
                    const SizedBox(height: 4),
                    _line(Icons.location_on, _vAddress, HBColors.mutedDark),
                    const Spacer(),
                    Text(_vOwner,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Template 3: Clean Stripe — white, bold orange bands ---------------
  Widget _stripeCard() {
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: HBColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              decoration: const BoxDecoration(
                color: HBColors.primary,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_vName,
                        style: const TextStyle(
                            color: HBColors.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    if (_vTagline.isNotEmpty)
                      Text(_vTagline,
                          style: const TextStyle(
                              color: HBColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                            child: _line(Icons.phone, _vPhone,
                                HBColors.muted)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _line(Icons.location_on,
                                _vAddress, HBColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: HBColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_vOwner,
                          style: const TextStyle(
                              color: HBColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final b = HiveService.currentBusiness;
    if (b == null) {
      final id = const Uuid().v4();
      await HiveService.business.put(
        id,
        BusinessProfile(
          id: id,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          ownerName: _owner.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      await HiveService.setBusinessId(id);
    } else {
      b.name = _name.text.trim();
      b.phone = _phone.text.trim();
      b.address = _address.text.trim();
      b.ownerName = _owner.text.trim();
      await HiveService.business.put(b.id, b);
    }
    if (!mounted) return;
    HBToast.show(context,
        message: careTr('care.cardSaved'), icon: Icons.check_circle);
  }

  /// Renders the visible card to PNG and shares it (WhatsApp-compatible).
  Future<void> _sharePng() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKeys[_template].currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await AppPaths.documentsDir();
      final file = File('${dir.path}/business_card.png');
      await file.writeAsBytes(
          bytes!.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      setState(() => _sharing = false);
      await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)], text: careTr('care.cardShareText')));
      if (mounted) {
        HBToast.show(context,
            message: careTr('care.cardShared'), icon: Icons.check_circle);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
      HBToast.show(context,
          message: careTr('care.backupFailed'),
          icon: Icons.error_outline);
    }
  }
}
