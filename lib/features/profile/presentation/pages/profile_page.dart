import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:url_launcher/url_launcher.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/driver_profile_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/driver_service.dart';
import 'package:kz_servicos_prestador/core/widgets/provider_bottom_nav.dart';
import 'package:kz_servicos_prestador/routes/app_router.dart';

class ProfilePage extends StatefulWidget {
  final ValueChanged<int> onNavTap;

  const ProfilePage({super.key, required this.onNavTap});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _driverService = DriverService();
  DriverProfileData? _profile;
  bool _loading = true;
  String? _avatarPath;
  bool _isUploadingPhoto = false;
  bool _isUploadingVehiclePhoto = false;
  bool _isUploadingDriverPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = AuthState.userId ?? '';
    final profile = await _driverService.getDriverProfile(userId);
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  Future<void> _onEditPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _avatarPath = picked.path;
      _isUploadingPhoto = true;
    });

    try {
      final userId = AuthState.userId!;
      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath = 'users/$userId/avatar.$ext';
      final supabase = Supabase.instance.client;

      await supabase.storage
          .from('Profile_Images')
          .upload(
            storagePath,
            File(picked.path),
            fileOptions: const FileOptions(upsert: true),
          );

      final ts = DateTime.now().millisecondsSinceEpoch;
      final publicUrl =
          '${supabase.storage.from('Profile_Images').getPublicUrl(storagePath)}?v=$ts';

      await supabase
          .from('users')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      if (mounted) {
        setState(() => _avatarPath = null);
        await _load();
      }
    } catch (e) {
      debugPrint('[KZ] avatar upload erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar foto. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _onAddVehiclePhoto() async {
    final vehicleId = _profile?.vehicle?.id;
    if (vehicleId == null || vehicleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um veículo antes de enviar foto.'),
        ),
      );
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingVehiclePhoto = true);
    try {
      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath =
          'vehicles/$vehicleId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final supabase = Supabase.instance.client;
      await supabase.storage
          .from('Vehicle_Photos')
          .upload(
            storagePath,
            File(picked.path),
            fileOptions: const FileOptions(upsert: false),
          );
      final publicUrl = supabase.storage
          .from('Vehicle_Photos')
          .getPublicUrl(storagePath);
      await supabase.from('vehicle_photos').insert({
        'vehicle_id': vehicleId,
        'photo_url': publicUrl,
        'photo_type': 'front',
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Foto do carro enviada.')));
      }
    } catch (e) {
      debugPrint('[KZ] vehicle photo upload erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar foto do carro.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingVehiclePhoto = false);
    }
  }

  Future<void> _onAddDriverPhoto() async {
    final driverProfileId = _profile?.driverProfileId;
    if (driverProfileId == null || driverProfileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil do motorista não encontrado.')),
      );
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingDriverPhoto = true);
    try {
      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath =
          'drivers/$driverProfileId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final supabase = Supabase.instance.client;
      await supabase.storage
          .from('Profile_Images')
          .upload(
            storagePath,
            File(picked.path),
            fileOptions: const FileOptions(upsert: false),
          );
      final publicUrl = supabase.storage
          .from('Profile_Images')
          .getPublicUrl(storagePath);
      await supabase.from('driver_profile_photos').insert({
        'driver_profile_id': driverProfileId,
        'photo_url': publicUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto do motorista enviada.')),
        );
      }
    } catch (e) {
      debugPrint('[KZ] driver photo upload erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar foto do motorista.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingDriverPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        24,
                        24,
                        bottomPadding + 100,
                      ),
                      child: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildOnlineStatus(),
                          const SizedBox(height: 16),
                          _buildStatsRow(),
                          const SizedBox(height: 24),
                          _buildSection('Veículo', [
                            _InfoRow(
                              icon: Icons.directions_car,
                              label: 'Modelo',
                              value: _profile?.vehicle?.fullModel ?? '-',
                            ),
                            _InfoRow(
                              icon: Icons.pin,
                              label: 'Placa',
                              value: _profile?.vehicle?.licensePlate ?? '-',
                            ),
                            _InfoRow(
                              icon: Icons.palette,
                              label: 'Cor',
                              value: _profile?.vehicle?.color ?? '-',
                            ),
                            _InfoRow(
                              icon: Icons.calendar_today,
                              label: 'Ano',
                              value: _profile?.vehicle?.year.toString() ?? '-',
                            ),
                            _ActionRow(
                              icon: Icons.add_a_photo_outlined,
                              label: _isUploadingVehiclePhoto
                                  ? 'Enviando foto...'
                                  : 'Adicionar foto do carro',
                              onTap: _isUploadingVehiclePhoto
                                  ? null
                                  : _onAddVehiclePhoto,
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _buildSection('Fotos do motorista', [
                            _ActionRow(
                              icon: Icons.add_photo_alternate_outlined,
                              label: _isUploadingDriverPhoto
                                  ? 'Enviando foto...'
                                  : 'Adicionar foto ao perfil público',
                              onTap: _isUploadingDriverPhoto
                                  ? null
                                  : _onAddDriverPhoto,
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _buildSection('Documentos', [
                            _InfoRow(
                              icon: Icons.credit_card,
                              label: 'CNH',
                              value: _profile?.cnhNumber ?? '-',
                            ),
                            _InfoRow(
                              icon: Icons.category,
                              label: 'Categoria',
                              value: _profile?.cnhCategory ?? '-',
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _buildMenuItems(),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned(
            bottom: bottomPadding + 12,
            left: 24,
            right: 24,
            child: ProviderBottomNav(
              selectedIndex: 3,
              onItemSelected: widget.onNavTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profile?.name ?? AuthState.userName ?? '';
    final email = _profile?.email ?? AuthState.userEmail ?? '';
    final initial = name.isNotEmpty ? name[0] : '?';

    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.highlight.withValues(alpha: 0.15),
              backgroundImage: _avatarPath != null
                  ? FileImage(File(_avatarPath!)) as ImageProvider
                  : (_profile?.avatarUrl != null &&
                            _profile!.avatarUrl!.isNotEmpty
                        ? NetworkImage(_profile!.avatarUrl!)
                        : null),
              child:
                  (_avatarPath == null &&
                      (_profile?.avatarUrl == null ||
                          _profile!.avatarUrl!.isEmpty))
                  ? Text(
                      initial,
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 36,
                        color: AppColors.highlight,
                      ),
                    )
                  : null,
            ),
            if (_isUploadingPhoto)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x66000000),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _onEditPhoto,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _isUploadingPhoto
                        ? Colors.grey.shade400
                        : AppColors.highlight,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'OutfitBlack',
            fontSize: 22,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildOnlineStatus() {
    final isAvailable = _profile?.isAvailable ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isAvailable
            ? const Color(0xFF2ECC71).withValues(alpha: 0.1)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAvailable
                  ? const Color(0xFF2ECC71)
                  : Colors.red.shade400,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAvailable ? 'Online' : 'Offline',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 14,
              color: isAvailable
                  ? const Color(0xFF2ECC71)
                  : Colors.red.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatCard(
          icon: Icons.star,
          value: (_profile?.averageRating ?? 0).toStringAsFixed(1),
          label: 'Avaliação',
          color: AppColors.highlight,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.directions_car,
          value: '${_profile?.totalRatings ?? 0}',
          label: 'Avaliações',
          color: AppColors.secondary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.calendar_today,
          value: 'Desde ${_profile?.memberSince ?? '-'}',
          label: 'Membro',
          color: const Color(0xFF2ECC71),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Central de Ajuda',
                style: TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _HelpContactRow(
                icon: Icons.phone_outlined,
                label: 'Telefone',
                value: '(11) 99999-0000',
                onTap: () => launchUrl(Uri.parse('tel:+5511999990000')),
              ),
              const Divider(height: 24),
              _HelpContactRow(
                icon: Icons.email_outlined,
                label: 'E-mail',
                value: 'contato@kzservicos.com.br',
                onTap: () =>
                    launchUrl(Uri.parse('mailto:contato@kzservicos.com.br')),
              ),
              const Divider(height: 24),
              _HelpContactRow(
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                value: 'Fale conosco',
                iconColor: const Color(0xFF25D366),
                onTap: () => launchUrl(
                  Uri.parse('https://wa.me/5511999990000'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Sair da conta',
          style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 18),
        ),
        content: const Text(
          'Tem certeza que deseja sair da sua conta?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppRouter.logout(context);
            },
            child: Text(
              'Sair',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.chat_outlined,
            label: 'Mensagens',
            onTap: () => context.push('/messages'),
          ),
          _MenuItem(
            icon: Icons.history_rounded,
            label: 'Histórico de corridas',
            onTap: () => context.push('/trip-history'),
          ),
          _MenuItem(
            icon: Icons.card_giftcard_rounded,
            label: 'Clube de benefícios',
            onTap: () => context.push('/benefits'),
          ),
          _MenuItem(
            icon: Icons.security_outlined,
            label: 'Segurança',
            onTap: () => context.push('/security-settings'),
          ),
          _MenuItem(
            icon: Icons.help_outline,
            label: 'Ajuda',
            onTap: () => _showHelpSheet(context),
          ),
          _MenuItem(
            icon: Icons.logout,
            label: 'Sair',
            color: Colors.red.shade400,
            onTap: () => _showLogoutDialog(context),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'OutfitBlack',
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'QuasimodoSemiBold',
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.highlight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: onTap == null
                      ? AppColors.textSecondary
                      : AppColors.highlight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final VoidCallback onTap;

  const _HelpContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppColors.secondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'QuasimodoSemiBold',
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.open_in_new,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showDivider;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: color ?? AppColors.textSecondary),
          title: Text(
            label,
            style: TextStyle(
              fontFamily: 'QuasimodoSemiBold',
              fontSize: 15,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: color ?? AppColors.textSecondary,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(height: 1, indent: 56, color: Colors.grey.shade200),
      ],
    );
  }
}
