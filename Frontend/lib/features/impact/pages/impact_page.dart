import 'package:flutter/material.dart';

class ImpactPage extends StatelessWidget {
  const ImpactPage({super.key});

  static const _ecoMint = Color(0xFF3CD4A0);
  static const _solarYellow = Color(0xFFFFD166);
  static const _vibrantCoral = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      color: t.scaffoldBackgroundColor, // ✅ fundo do tema
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HighlightCard(
            title: 'Esta semana',
            subtitle: 'Resumo ecológico',
            value: '−1,8 kg CO₂',
            icon: Icons.eco,
            color: _ecoMint,
          ),
          const SizedBox(height: 16),

          Row(
            children: const [
              Expanded(
                child: _StatTile(
                  label: 'Kms percorridos',
                  value: '42,5',
                  suffix: 'km',
                  icon: Icons.directions_car_filled,
                  color: _solarYellow,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Rotas Eco',
                  value: '68%',
                  suffix: '',
                  icon: Icons.energy_savings_leaf,
                  color: _ecoMint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _StatTile(
            label: 'Tempo poupado',
            value: '34',
            suffix: 'min',
            icon: Icons.timer,
            color: _vibrantCoral,
          ),

          const SizedBox(height: 24),

          Text(
            'Metas',
            style: t.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              color: t.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          const _GoalRow(label: '3 dias/semana em modo Eco', progress: 0.66),
          const SizedBox(height: 8),
          const _GoalRow(label: '−5% CO₂ face ao mês passado', progress: 0.40),

          const SizedBox(height: 24),
          Text(
            'Estimativas com base em distância × fator de emissão. Os valores podem variar conforme o trânsito e o modo.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: t.colorScheme.onSurface.withOpacity(.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _HighlightCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: t.cardColor, // ✅ card dark no dark
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        border: Border.all(color: t.brightness == Brightness.dark ? Colors.white10 : const Color(0x143CD4A0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withOpacity(.16),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: t.textTheme.titleLarge?.copyWith(fontSize: 16, color: t.colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: t.colorScheme.onSurface.withOpacity(.7)),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      height: 88,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.cardColor, // ✅ card dark
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
        border: Border.all(color: t.brightness == Brightness.dark ? Colors.white10 : const Color(0x143CD4A0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: color.withOpacity(.16), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: t.colorScheme.onSurface)),
          ),
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: t.colorScheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: ' $suffix',
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 12, color: t.colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String label;
  final double progress;
  const _GoalRow({required this.label, required this.progress});

  static const _ecoMint = Color(0xFF3CD4A0);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: t.colorScheme.onSurface)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: t.brightness == Brightness.dark ? Colors.white12 : const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(_ecoMint),
          ),
        ),
      ],
    );
  }
}
