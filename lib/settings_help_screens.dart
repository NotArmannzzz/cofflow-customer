part of 'main.dart';

const String kAppVersion = '1.0.0';

InputDecoration _fieldDecoration(String label, {Widget? suffix}) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEAEAEA))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEAEAEA))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kBrandDark)),
    );

Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1)),
    );

Widget _primaryButton(String label, {required bool loading, VoidCallback? onPressed}) =>
    SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kBrandDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kBrandDark.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

void _snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : kBrandDark,
      behavior: SnackBarBehavior.floating,
    ));
}

// ─────────────────────────────────────────────────────────
// SETTINGS SCREEN — dibuka dari menu "Pengaturan" di profil
// ─────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.profile});
  final UserProfile? profile;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile?.fullName ?? '');
  late final _phone = TextEditingController(text: widget.profile?.phone ?? '');
  final _oldPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _showPw = false;
  bool _changed = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _oldPw, _newPw, _confirmPw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileForm.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      await AuthService.updateProfile(
          name: _name.text.trim(), phone: _phone.text.trim());
      _changed = true;
      if (mounted) _snack(context, 'Profil berhasil diperbarui');
    } catch (e) {
      if (mounted) _snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      await AuthService.changePassword(
          oldPassword: _oldPw.text, newPassword: _newPw.text);
      _oldPw.clear();
      _newPw.clear();
      _confirmPw.clear();
      if (mounted) _snack(context, 'Password berhasil diubah');
    } catch (e) {
      if (mounted) _snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Widget _eye() => IconButton(
        icon: Icon(_showPw ? LucideIcons.eyeOff : LucideIcons.eye,
            size: 18, color: Colors.grey),
        onPressed: () => setState(() => _showPw = !_showPw),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: kBrandLight,
        body: Column(children: [
          const _SubPageHeader(title: 'pengaturan.'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('PROFIL'),
                    Form(
                      key: _profileForm,
                      child: Column(children: [
                        TextFormField(
                          controller: _name,
                          decoration: _fieldDecoration('Nama lengkap'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Nama wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDecoration('Nomor HP'),
                          validator: (v) => (v != null && v.trim().length > 20)
                              ? 'Maksimal 20 karakter'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _primaryButton('Simpan Profil',
                            loading: _savingProfile, onPressed: _saveProfile),
                      ]),
                    ),
                    const SizedBox(height: 32),
                    _sectionLabel('GANTI PASSWORD'),
                    Form(
                      key: _passwordForm,
                      child: Column(children: [
                        TextFormField(
                          controller: _oldPw,
                          obscureText: !_showPw,
                          decoration:
                              _fieldDecoration('Password lama', suffix: _eye()),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Password lama wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPw,
                          obscureText: !_showPw,
                          decoration: _fieldDecoration('Password baru'),
                          validator: (v) => (v == null || v.length < 8)
                              ? 'Minimal 8 karakter'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPw,
                          obscureText: !_showPw,
                          decoration:
                              _fieldDecoration('Konfirmasi password baru'),
                          validator: (v) => v != _newPw.text
                              ? 'Konfirmasi password tidak sama'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _primaryButton('Ubah Password',
                            loading: _savingPassword, onPressed: _savePassword),
                      ]),
                    ),
                    const SizedBox(height: 32),
                    _sectionLabel('TENTANG APLIKASI'),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F1F1))),
                      child: const Row(children: [
                        Icon(LucideIcons.info, size: 20, color: kBrandDark),
                        SizedBox(width: 16),
                        Expanded(
                            child: Text('Konco Space',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: kBrandDark))),
                        Text('v$kAppVersion',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HELP SCREEN — dibuka dari menu "Bantuan" di profil.
// FAQ & kontak dikelola admin di webadmin (menu Bantuan & Info).
// ─────────────────────────────────────────────────────────
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late Future<AppInfo> _future = AppInfoService.fetch();

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    _snack(context, '$label disalin: $value');
  }

  Widget _contactTile(IconData icon, String label, String? value,
      {String? copyValue}) {
    if (value == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _copy(label, copyValue ?? value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: kBrandAccent, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ]),
          ),
          const Icon(LucideIcons.copy, color: Colors.white38, size: 14),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandLight,
      body: Column(children: [
        const _SubPageHeader(title: 'bantuan.'),
        Expanded(
          child: FutureBuilder<AppInfo>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                    child: CircularProgressIndicator(color: kBrandDark));
              }
              if (snap.hasError) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(snap.error.toString(),
                        style: const TextStyle(color: Colors.grey)),
                    TextButton(
                        onPressed: () =>
                            setState(() => _future = AppInfoService.fetch()),
                        child: const Text('Coba lagi')),
                  ]),
                );
              }
              final info = snap.data!;
              final s = info.store;
              return RefreshIndicator(
                color: kBrandDark,
                onRefresh: () async {
                  final f = AppInfoService.fetch();
                  setState(() => _future = f);
                  await f;
                },
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SupportChatScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: kBrandAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Row(children: [
                        Icon(LucideIcons.messageCircle, color: kBrandDark),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Chat dengan CS',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kBrandDark)),
                                SizedBox(height: 2),
                                Text('Tanya langsung ke tim kami',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                              ]),
                        ),
                        Icon(LucideIcons.chevronRight,
                            color: Colors.grey, size: 18),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('PERTANYAAN UMUM'),
                  if (info.faqs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Belum ada FAQ',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  for (final f in info.faqs)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF1F1F1))),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(18, 0, 18, 16),
                          iconColor: kBrandDark,
                          collapsedIconColor: Colors.grey,
                          title: Text(f.question,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: kBrandDark)),
                          expandedAlignment: Alignment.centerLeft,
                          children: [
                            Text(f.answer,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    height: 1.5)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _sectionLabel('HUBUNGI ${s.storeName.toUpperCase()}'),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: kBrandDark,
                        borderRadius: BorderRadius.circular(28)),
                    child: Column(children: [
                      _contactTile(LucideIcons.clock, 'Jam buka', s.openingHours),
                      _contactTile(LucideIcons.mapPin, 'Alamat', s.address),
                      _contactTile(LucideIcons.messageSquare, 'WhatsApp',
                          s.whatsapp == null ? null : '+${s.whatsapp}',
                          copyValue: s.whatsapp),
                      _contactTile(LucideIcons.phone, 'Telepon', s.phone),
                      _contactTile(LucideIcons.mail, 'Email', s.email),
                      _contactTile(LucideIcons.atSign, 'Instagram',
                          s.instagram == null ? null : '@${s.instagram}'),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('Ketuk kontak untuk menyalin',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SUPPORT CHAT — terhubung ke menu "Chat CS" di webadmin
// ─────────────────────────────────────────────────────────
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});
  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<SupportMessage> _messages = [];
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _fetchNew());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await SupportService.fetchMessages();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(items);
        _loading = false;
        _error = null;
      });
      _toBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _fetchNew() async {
    if (_loading || _messages.isEmpty && _error != null) return;
    try {
      final items = await SupportService.fetchMessages(
          afterId: _messages.isEmpty ? null : _messages.last.id);
      final known = _messages.map((m) => m.id).toSet();
      final fresh = items.where((m) => !known.contains(m.id)).toList();
      if (!mounted || fresh.isEmpty) return;
      setState(() => _messages.addAll(fresh));
      _toBottom();
    } catch (_) {
      // polling: abaikan error sementara
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await SupportService.send(text);
      if (!mounted) return;
      _input.clear();
      setState(() {
        if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
      });
      _toBottom();
    } catch (e) {
      if (mounted) _snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  String _time(DateTime? d) => d == null
      ? ''
      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandLight,
      body: Column(children: [
        const _SubPageHeader(title: 'chat cs.'),
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
                  : _messages.isEmpty
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                              'Belum ada pesan.\nTulis pertanyaanmu, tim kami akan membalas secepatnya.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        ))
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(20),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final m = _messages[i];
                            final mine = m.fromCustomer;
                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.75),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: mine ? kBrandDark : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(m.body,
                                          style: TextStyle(
                                              color: mine
                                                  ? Colors.white
                                                  : kBrandDark)),
                                      const SizedBox(height: 4),
                                      Text(_time(m.createdAt),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: mine
                                                  ? Colors.white54
                                                  : Colors.grey)),
                                    ]),
                              ),
                            );
                          },
                        ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            color: Colors.white,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                      hintText: 'Tulis pesan...',
                      counterText: '',
                      border: InputBorder.none),
                ),
              ),
              IconButton(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kBrandDark))
                    : const Icon(LucideIcons.send, color: kBrandDark),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
