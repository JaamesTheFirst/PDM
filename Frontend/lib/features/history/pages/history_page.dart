import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      color: t.scaffoldBackgroundColor, // ✅ fundo do tema (preto no dark)
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: t.colorScheme.onSurface.withOpacity(.6)),
            const SizedBox(height: 12),
            Text(
              'O teu histórico vai aparecer aqui',
              style: TextStyle(fontSize: 16, color: t.colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'Planeia um trajeto para começares a registar.',
              style: TextStyle(fontSize: 14, color: t.colorScheme.onSurface.withOpacity(.7)),
            ),
          ],
        ),
      ),
    );
  }
}
