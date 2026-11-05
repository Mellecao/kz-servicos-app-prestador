import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Segurança',
          style: TextStyle(
            fontFamily: 'OutfitBlack',
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _SettingTile(
              icon: Icons.lock_outline,
              title: 'Alterar palavra-passe',
              subtitle: 'Atualize a sua palavra-passe de acesso',
              onTap: () => _showChangeDialog(
                context,
                title: 'Alterar palavra-passe',
                fields: [
                  'Palavra-passe atual',
                  'Nova palavra-passe',
                  'Confirmar nova palavra-passe',
                ],
                obscure: true,
              ),
            ),
            const SizedBox(height: 12),
            _SettingTile(
              icon: Icons.email_outlined,
              title: 'Alterar e-mail',
              subtitle: 'Atualize o seu endereço de e-mail',
              onTap: () => _showChangeDialog(
                context,
                title: 'Alterar e-mail',
                fields: ['Novo e-mail', 'Palavra-passe para confirmar'],
                obscure: false,
              ),
            ),
            const SizedBox(height: 12),
            _SettingTile(
              icon: Icons.phone_outlined,
              title: 'Alterar telemóvel',
              subtitle: 'Atualize o seu número de telemóvel',
              onTap: () => _showChangeDialog(
                context,
                title: 'Alterar telemóvel',
                fields: ['Novo telemóvel', 'Palavra-passe para confirmar'],
                obscure: false,
              ),
            ),
            const SizedBox(height: 32),
            _SettingTile(
              icon: Icons.delete_forever_outlined,
              title: 'Eliminar conta',
              subtitle: 'Esta ação é irreversível',
              color: Colors.red.shade400,
              onTap: () => _showDeleteConfirmation(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeDialog(
    BuildContext context, {
    required String title,
    required List<String> fields,
    required bool obscure,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(fontFamily: 'OutfitBlack', fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  obscureText:
                      obscure && field.toLowerCase().contains('palavra-passe'),
                  decoration: InputDecoration(
                    labelText: field,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alteração salva com sucesso!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.highlight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Eliminar conta',
            style: TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 18,
              color: Colors.red,
            ),
          ),
          content: const Text(
            'Tem a certeza de que pretende eliminar a sua conta? '
            'Todos os dados serão perdidos permanentemente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tileColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 15,
                      color: tileColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tileColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
