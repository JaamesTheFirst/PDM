import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/state/theme_controller.dart';
import '../../auth/state/auth_controller.dart';

/// Página de definições da aplicação.
///
/// Actualmente expõe:
/// - Controlo do tema (sistema / claro / escuro).
/// - Acção para terminar sessão do utilizador.
///
/// Esta página assume que:
/// - Existe um [ThemeController] registado no `Provider` à volta da árvore.
/// - Existe um [AuthController] responsável pela lógica de autenticação e logout.
/// - As rotas incluem uma named route `/login` para onde o utilizador é
///   redireccionado após terminar sessão.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeCtrl = context.watch<ThemeController>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        /// Secção de aparência (tema da aplicação).
        _SectionCard(
          title: 'Aparência',
          child: Column(
            children: [
              /// Usa o tema do sistema operativo (iOS / Android).
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeCtrl.themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    context.read<ThemeController>().setThemeMode(mode);
                  }
                },
                title: const Text('Seguir o sistema'),
                secondary: const Icon(Icons.phone_iphone),
              ),

              /// Força tema claro independentemente das definições do sistema.
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeCtrl.themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    context.read<ThemeController>().setThemeMode(mode);
                  }
                },
                title: const Text('Tema claro'),
                secondary: const Icon(Icons.light_mode),
              ),

              /// Força tema escuro independentemente das definições do sistema.
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeCtrl.themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    context.read<ThemeController>().setThemeMode(mode);
                  }
                },
                title: const Text('Tema escuro'),
                secondary: const Icon(Icons.dark_mode),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        /// Secção relacionada com a conta do utilizador (autenticação).
        _SectionCard(
          title: 'Conta',
          child: ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            title: const Text(
              'Terminar sessão',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              // Lê o controlador de autenticação a partir do Provider.
              final auth = context.read<AuthController>();

              // Executa o fluxo de logout (limpar token / estado local, etc.).
              await auth.logout();

              // Garante que o contexto ainda está montado antes de navegar.
              if (!context.mounted) return;

              // Redirecciona o utilizador para a página de login e limpa
              // completamente a stack de navegação.
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (_) => false,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Card reutilizável para agrupar uma secção de definições.
///
/// Aplica um estilo consistente aos blocos de conteúdo:
/// - Fundo com [ThemeData.cardColor].
/// - Cantos arredondados.
/// - Sombra leve.
/// - Título destacado seguido do conteúdo (child).
class _SectionCard extends StatelessWidget {
  /// Título apresentado no topo do card (ex.: "Aparência", "Conta").
  final String title;

  /// Conteúdo da secção (tipicamente uma coluna com ListTiles).
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da secção
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ),

          // Conteúdo propriamente dito (widgets passados via [child]).
          child,
        ],
      ),
    );
  }
}
