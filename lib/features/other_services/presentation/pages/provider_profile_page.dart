import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:url_launcher/url_launcher.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/category_colors.dart';
import 'package:kz_servicos_prestador/core/models/provider_profile_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/provider_service.dart';
import 'package:kz_servicos_prestador/core/widgets/service_provider_bottom_nav.dart';
import 'package:kz_servicos_prestador/routes/app_router.dart';

class ProviderProfilePage extends StatefulWidget {
  final ValueChanged<int> onNavTap;

  const ProviderProfilePage({super.key, required this.onNavTap});

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  final _service = ProviderService();
  ProviderProfileData? _profile;
  bool _loading = true;
  String? _avatarPath;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = AuthState.userId ?? '';
    final profile = await _service.getProviderProfile(userId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

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
                      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 100),
                      child: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildOnlineStatus(),
                          const SizedBox(height: 16),
                          _buildStatsRow(),
                          const SizedBox(height: 24),
                          _buildCategoriesSection(),
                          const SizedBox(height: 16),
                          _buildMenuItems(),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned(
            bottom: bottomPad + 12,
            left: 24,
            right: 24,
            child: ServiceProviderBottomNav(
              selectedIndex: 2,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2ECC71),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Online',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 14,
              color: Color(0xFF2ECC71),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final rating = _profile?.averageRating ?? 0;
    final totalRatings = _profile?.totalRatings ?? 0;
    final memberSince = _profile?.memberSince ?? '-';

    return Row(
      children: [
        _StatCard(
          icon: Icons.star,
          value: rating.toStringAsFixed(1),
          label: 'Avaliação',
          color: AppColors.highlight,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.handyman_rounded,
          value: '$totalRatings',
          label: 'Serviços',
          color: AppColors.secondary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.calendar_today,
          value: 'Desde $memberSince',
          label: 'Membro',
          color: const Color(0xFF2ECC71),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    final categories = _profile?.serviceCategories ?? const <String>[];

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
          const Text(
            'Categorias de serviço',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const Text(
              'Nenhuma categoria cadastrada',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final color = categoryColorFor(cat);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontFamily: 'QuasimodoSemiBold',
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
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
              _HelpRow(
                icon: Icons.phone_outlined,
                label: 'Telefone',
                value: '(11) 99999-0000',
                onTap: () => launchUrl(Uri.parse('tel:+5511999990000')),
              ),
              const Divider(height: 24),
              _HelpRow(
                icon: Icons.email_outlined,
                label: 'E-mail',
                value: 'contato@kzservicos.com.br',
                onTap: () =>
                    launchUrl(Uri.parse('mailto:contato@kzservicos.com.br')),
              ),
              const Divider(height: 24),
              _HelpRow(
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
            label: 'Histórico de serviços',
            onTap: () {},
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

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final VoidCallback onTap;

  const _HelpRow({
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
