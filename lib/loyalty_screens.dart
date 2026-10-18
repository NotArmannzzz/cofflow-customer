part of 'main.dart';

String _rupiah(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp$buf';
}

String _shortDate(DateTime? d) {
  if (d == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String _rewardBenefit(PointReward r) {
  final main = r.type == 'percentage'
      ? 'Diskon ${r.value.round()}%${r.maxDiscount != null ? ' (maks ${_rupiah(r.maxDiscount!)})' : ''}'
      : 'Potongan ${_rupiah(r.value)}';
  return r.minOrder > 0 ? '$main · min. belanja ${_rupiah(r.minOrder)}' : main;
}

const Map<String, Color> _tierColors = {
  'bronze': Color(0xFFB0793F),
  'silver': Color(0xFF9EA4AA),
  'gold': kBrandAccent,
};

// ─────────────────────────────────────────────────────────
// LOYALTY — saldo poin, tier, benefit, tukar reward, voucher, riwayat
// ─────────────────────────────────────────────────────────
class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});
  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  LoyaltySummary? _summary;
  List<PointReward> _rewards = [];
  List<UserVoucher> _vouchers = [];
  List<PointHistory> _history = [];
  bool _loading = true;
  String? _error;
  int _tab = 0; // 0 reward, 1 voucher, 2 riwayat
  int? _redeemingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _summary == null;
      _error = null;
    });
    try {
      final results = await Future.wait([
        LoyaltyService.summary(),
        LoyaltyService.rewards(),
        LoyaltyService.vouchers(),
        LoyaltyService.history(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as LoyaltySummary;
        _rewards = results[1] as List<PointReward>;
        _vouchers = results[2] as List<UserVoucher>;
        _history = results[3] as List<PointHistory>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _redeem(PointReward r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tukar poin?'),
        content: Text(
            'Tukar ${r.pointsCost} poin dengan "${r.name}"?\n\n${_rewardBenefit(r)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tukar',
                  style: TextStyle(fontWeight: FontWeight.bold, color: kBrandDark))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _redeemingId = r.id);
    try {
      final v = await LoyaltyService.redeem(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Berhasil! Voucher ${v.name} (${v.code}) ada di tab Voucher Saya')));
      setState(() => _tab = 1);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _redeemingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandLight,
      body: Column(children: [
        const _SubPageHeader(title: 'poin & member.'),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kBrandDark))
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                      ),
                      TextButton(onPressed: _load, child: const Text('Coba lagi')),
                    ]))
                  : RefreshIndicator(
                      color: kBrandDark,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _memberCard(_summary!),
                          if (!_summary!.enabled) ...[
                            const SizedBox(height: 12),
                            const Text(
                                'Program poin sedang tidak aktif. Poin tidak bertambah dan reward tidak bisa ditukar sementara.',
                                style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ],
                          const SizedBox(height: 28),
                          _sectionTitle('Level Member & Benefit'),
                          const SizedBox(height: 12),
                          ..._summary!.tiers.map(_tierTile),
                          const SizedBox(height: 16),
                          _howToEarn(_summary!),
                          const SizedBox(height: 28),
                          _tabs(),
                          const SizedBox(height: 16),
                          ...switch (_tab) {
                            0 => _rewardList(),
                            1 => _voucherList(),
                            _ => _historyList(),
                          },
                        ],
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.bold, color: kBrandDark));

  Widget _memberCard(LoyaltySummary s) {
    final tierColor = _tierColors[s.tier] ?? kBrandAccent;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: kBrandDark, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: tierColor)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.award, size: 14, color: tierColor),
              const SizedBox(width: 6),
              Text('MEMBER ${(kTierLabels[s.tier] ?? s.tier).toUpperCase()}',
                  style: TextStyle(
                      color: tierColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        const Text('SALDO POIN',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${s.pointsBalance}',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, height: 1)),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('poin', style: TextStyle(color: Colors.white70)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Total poin yang pernah didapat: ${s.lifetimePoints}',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: s.progress,
            minHeight: 8,
            backgroundColor: Colors.white12,
            color: kBrandAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
            s.nextTier == null
                ? 'Kamu sudah di level tertinggi'
                : '${s.pointsToNextTier} poin lagi menuju ${kTierLabels[s.nextTier] ?? s.nextTier}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _tierTile(TierThreshold t) {
    final current = _summary!.tier == t.tier;
    final reached = _summary!.lifetimePoints >= t.threshold;
    final color = _tierColors[t.tier] ?? kBrandAccent;
    final exclusive = _rewards.where((r) => r.minTier == t.tier).toList();

    final benefits = <String>[
      if (t.tier == 'bronze') 'Dapat poin dari setiap pesanan lewat aplikasi',
      if (t.tier != 'bronze')
        'Semua benefit ${kTierLabels[_prevTier(t.tier)] ?? ''}',
      ...exclusive.map((r) => 'Bisa tukar: ${r.name} (${r.pointsCost} poin)'),
      if (exclusive.isEmpty && t.tier != 'bronze') 'Akses reward khusus level ${kTierLabels[t.tier]}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: current ? color : const Color(0xFFF1F1F1), width: current ? 2 : 1)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: reached ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(reached ? LucideIcons.award : LucideIcons.lock,
              size: 20, color: reached ? color : Colors.grey),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(kTierLabels[t.tier] ?? t.tier,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: kBrandDark)),
              const SizedBox(width: 8),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: kBrandDark, borderRadius: BorderRadius.circular(100)),
                  child: const Text('LEVEL KAMU',
                      style: TextStyle(
                          color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
            ]),
            Text(
                t.threshold == 0
                    ? 'Otomatis saat daftar'
                    : 'Total poin didapat ≥ ${t.threshold}',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 8),
            ...benefits.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(LucideIcons.check, size: 12, color: Colors.green),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(b,
                            style: const TextStyle(fontSize: 12, color: kBrandDark))),
                  ]),
                )),
          ]),
        ),
      ]),
    );
  }

  String _prevTier(String tier) => switch (tier) {
        'gold' => 'silver',
        _ => 'bronze',
      };

  Widget _howToEarn(LoyaltySummary s) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kBrandAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(LucideIcons.info, size: 16, color: kBrandDark),
            SizedBox(width: 8),
            Text('Cara dapat poin',
                style: TextStyle(fontWeight: FontWeight.bold, color: kBrandDark)),
          ]),
          const SizedBox(height: 8),
          Text(
            '• Setiap 1 menu seharga ≥ ${_rupiah(s.minItemPrice)} = 1 poin (cek label "+poin" di menu).\n'
            '• Poin masuk saat pesanan berstatus Selesai.\n'
            '• Level naik berdasarkan total poin yang pernah didapat, jadi menukar poin tidak menurunkan level.',
            style: const TextStyle(fontSize: 12, height: 1.6, color: kBrandDark),
          ),
        ]),
      );

  Widget _tabs() {
    const labels = ['Tukar Poin', 'Voucher Saya', 'Riwayat'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: kBrandMuted, borderRadius: BorderRadius.circular(100)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: active ? kBrandDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(100)),
                alignment: Alignment.center,
                child: Text(labels[i],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.white : Colors.grey)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(text,
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      );

  List<Widget> _rewardList() {
    if (_rewards.isEmpty) return [_empty('Belum ada reward yang bisa ditukar')];
    final balance = _summary!.pointsBalance;
    return _rewards.map((r) {
      final busy = _redeemingId == r.id;
      final String? blocker = r.soldOut
          ? 'Kuota habis'
          : r.tierLocked
              ? 'Khusus ${kTierLabels[r.minTier] ?? r.minTier}'
              : balance < r.pointsCost
                  ? 'Kurang ${r.pointsCost - balance} poin'
                  : null;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F1F1))),
        child: Row(children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: kBrandAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('${r.pointsCost}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: kBrandDark)),
              const Text('poin', style: TextStyle(fontSize: 9, color: kBrandDark)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kBrandDark)),
              const SizedBox(height: 2),
              Text(_rewardBenefit(r),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (r.description.isNotEmpty)
                Text(r.description,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (r.minTier != 'bronze')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Level ${kTierLabels[r.minTier]} ke atas',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _tierColors[r.minTier] ?? kBrandAccent)),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          blocker != null
              ? SizedBox(
                  width: 72,
                  child: Text(blocker,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                )
              : ElevatedButton(
                  onPressed: busy || _redeemingId != null ? null : () => _redeem(r),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kBrandDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100))),
                  child: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('TUKAR',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
        ]),
      );
    }).toList();
  }

  List<Widget> _voucherList() {
    if (_vouchers.isEmpty) {
      return [_empty('Belum punya voucher.\nTukar poinmu di tab "Tukar Poin".')];
    }
    const statusLabel = {
      'available': ('Bisa dipakai', Colors.green),
      'used': ('Sudah dipakai', Colors.grey),
      'expired': ('Kedaluwarsa', Colors.redAccent),
    };
    return _vouchers.map((v) {
      final (label, color) = statusLabel[v.status] ?? (v.status, Colors.grey);
      final active = v.status == 'available';
      return Opacity(
        opacity: active ? 1 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active ? kBrandAccent : const Color(0xFFF1F1F1))),
          child: Row(children: [
            const Icon(LucideIcons.ticket, color: kBrandDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kBrandDark)),
                Text('Kode: ${v.code}',
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace', color: kBrandDark)),
                if (v.minOrder > 0)
                  Text('Min. belanja ${_rupiah(v.minOrder)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (v.expiresAt != null)
                  Text('Berlaku s/d ${_shortDate(v.expiresAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
            active
                ? ElevatedButton(
                    onPressed: () => _useVoucher(v),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kBrandDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100))),
                    child: Text(
                        AppState.selectedVoucher?.id == v.id ? 'DIPILIH' : 'PAKAI',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : Text(label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      );
    }).toList();
  }

  void _useVoucher(UserVoucher v) {
    final messenger = ScaffoldMessenger.of(context);
    AppState.selectedVoucher = v;
    Navigator.of(context).popUntil((r) => r.isFirst);
    AppState.changeTab(2);
    messenger.showSnackBar(SnackBar(
        content: Text(AppState.cart.isEmpty
            ? 'Voucher ${v.name} dipilih. Tambahkan menu ke keranjang lalu checkout.'
            : 'Voucher ${v.name} dipakai di keranjang')));
  }

  List<Widget> _historyList() {
    if (_history.isEmpty) {
      return [_empty('Belum ada riwayat poin.\nPoin masuk saat pesananmu selesai.')];
    }
    return _history.map((h) {
      final plus = h.points >= 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F1F1))),
        child: Row(children: [
          Icon(
              h.type == 'redeem'
                  ? LucideIcons.gift
                  : h.type == 'adjust'
                      ? LucideIcons.slidersHorizontal
                      : LucideIcons.plusCircle,
              size: 18,
              color: plus ? Colors.green : Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.description,
                  style: const TextStyle(fontSize: 13, color: kBrandDark)),
              Text(_shortDate(h.createdAt),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
          Text('${plus ? '+' : ''}${h.points}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: plus ? Colors.green : Colors.redAccent)),
        ]),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────
// NOTIFICATIONS — /notifications
// ─────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await NotificationService.fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAll() async {
    try {
      await NotificationService.markAllRead();
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n.isRead = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _open(AppNotification n) {
    if (!n.isRead) {
      setState(() => n.isRead = true);
      NotificationService.markRead(n.id).catchError((_) {});
    }
    if (n.type == 'points_earned' || n.type == 'tier_up') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyScreen()));
    }
  }

  IconData _icon(String type) => switch (type) {
        'order_status' => LucideIcons.receipt,
        'payment_confirmed' => LucideIcons.creditCard,
        'points_earned' => LucideIcons.star,
        'tier_up' => LucideIcons.award,
        _ => LucideIcons.bell,
      };

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => !n.isRead);
    return Scaffold(
      backgroundColor: kBrandLight,
      body: Column(children: [
        Stack(children: [
          const _SubPageHeader(title: 'notifikasi.'),
          if (hasUnread)
            Positioned(
              right: 12,
              bottom: 22,
              child: TextButton(
                onPressed: _markAll,
                child: const Text('Tandai dibaca',
                    style: TextStyle(color: kBrandDark, fontSize: 12)),
              ),
            ),
        ]),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kBrandDark))
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                      TextButton(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          child: const Text('Coba lagi')),
                    ]))
                  : RefreshIndicator(
                      color: kBrandDark,
                      onRefresh: _load,
                      child: _items.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: 120),
                              Icon(LucideIcons.bellOff,
                                  size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text('Belum ada notifikasi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey)),
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _items.length,
                              itemBuilder: (_, i) {
                                final n = _items[i];
                                return GestureDetector(
                                  onTap: () => _open(n),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                        color: n.isRead
                                            ? Colors.white
                                            : kBrandAccent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(18),
                                        border:
                                            Border.all(color: const Color(0xFFF1F1F1))),
                                    child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                                color: kBrandDark,
                                                borderRadius: BorderRadius.circular(12)),
                                            child: Icon(_icon(n.type),
                                                size: 16, color: kBrandAccent),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(n.title,
                                                      style: TextStyle(
                                                          fontWeight: n.isRead
                                                              ? FontWeight.w600
                                                              : FontWeight.bold,
                                                          color: kBrandDark)),
                                                  const SizedBox(height: 2),
                                                  Text(n.body,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black54)),
                                                  const SizedBox(height: 4),
                                                  Text(_shortDate(n.createdAt),
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey)),
                                                ]),
                                          ),
                                          if (!n.isRead)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle),
                                            ),
                                        ]),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
// VOUCHER PICKER — dipakai di keranjang
// ─────────────────────────────────────────────────────────
class _VoucherPick {
  const _VoucherPick(this.voucher);
  final UserVoucher? voucher; // null = tanpa voucher
}

class VoucherPickerSheet extends StatefulWidget {
  const VoucherPickerSheet({super.key, this.selectedId});
  final int? selectedId;
  @override
  State<VoucherPickerSheet> createState() => _VoucherPickerSheetState();
}

class _VoucherPickerSheetState extends State<VoucherPickerSheet> {
  List<UserVoucher>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await LoyaltyService.vouchers();
      if (!mounted) return;
      setState(() => _items = all.where((v) => v.status == 'available').toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Voucher Poin',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        Flexible(child: _body()),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => const LoyaltyScreen()));
          },
          icon: const Icon(LucideIcons.gift, size: 16, color: kBrandDark),
          label: const Text('Tukar poin jadi voucher',
              style: TextStyle(color: kBrandDark, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.grey));
    }
    if (_items == null) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: kBrandDark));
    }
    if (_items!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Kamu belum punya voucher yang bisa dipakai.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView(shrinkWrap: true, children: [
      if (widget.selectedId != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.ban, color: Colors.grey),
          title: const Text('Tanpa voucher'),
          onTap: () => Navigator.pop(context, const _VoucherPick(null)),
        ),
      ..._items!.map((v) {
        final selected = v.id == widget.selectedId;
        final benefit = v.type == 'percentage'
            ? 'Diskon ${v.value.round()}%${v.maxDiscount != null ? ' (maks ${_rupiah(v.maxDiscount!)})' : ''}'
            : 'Potongan ${_rupiah(v.value)}';
        return GestureDetector(
          onTap: () => Navigator.pop(context, _VoucherPick(v)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: selected ? kBrandAccent.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: selected ? kBrandAccent : const Color(0xFFF1F1F1),
                    width: selected ? 2 : 1)),
            child: Row(children: [
              const Icon(LucideIcons.ticket, color: kBrandDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: kBrandDark)),
                  Text(
                      v.minOrder > 0
                          ? '$benefit · min. belanja ${_rupiah(v.minOrder)}'
                          : benefit,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  if (v.expiresAt != null)
                    Text('Berlaku s/d ${_shortDate(v.expiresAt)}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ]),
              ),
              Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  color: selected ? kBrandDark : Colors.grey.shade300),
            ]),
          ),
        );
      }),
    ]);
  }
}
