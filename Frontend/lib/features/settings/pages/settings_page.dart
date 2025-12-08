import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/state/theme_controller.dart';
import '../../auth/state/auth_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final themeCtrl = context.watch<ThemeController>();
    final isDark = t.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Aparência',
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeCtrl.themeMode,
                onChanged: (m) => context.read<ThemeController>().setThemeMode(m!),
                title: const Text('Seguir o sistema'),
                secondary: const Icon(Icons.phone_iphone),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeCtrl.themeMode,
                onChanged: (m) => context.read<ThemeController>().setThemeMode(m!),
                title: const Text('Tema claro'),
                secondary: const Icon(Icons.light_mode),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeCtrl.themeMode,
                onChanged: (m) => context.read<ThemeController>().setThemeMode(m!),
                title: const Text('Tema escuro'),
                secondary: const Icon(Icons.dark_mode),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Preferências',
          child: Column(
            children: [
              SwitchListTile(
                value: true,
                onChanged: (_) {},
                title: const Text('Sugestões Eco'),
                subtitle: const Text('Priorizar rotas com menor CO₂'),
              ),
              SwitchListTile(
                value: !isDark,
                onChanged: (_) {},
                title: const Text('Vibração háptica'),
                subtitle: const Text('Feedback tátil ao tocar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Conta',
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Terminar sessão', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final auth = context.read<AuthController>();
              await auth.logout();
              if (!context.mounted) return;
              // Navigate to login and clear navigation stack
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(title,
                style: t.textTheme.titleLarge?.copyWith(fontSize: 18)),
          ),
          child,
        ],
      ),
    );
  }
}
