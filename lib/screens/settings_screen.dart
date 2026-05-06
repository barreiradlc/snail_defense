import 'package:flutter/material.dart';
import '../models/game_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GameSettings? _settings;

  @override
  void initState() {
    super.initState();
    GameSettings.load().then((s) => setState(() => _settings = s));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B4332)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _settings == null
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Configurações',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(label: '🎵 Áudio'),
                const SizedBox(height: 24),
                _SliderSetting(
                  label: 'Volume da Música',
                  icon: Icons.music_note,
                  value: _settings!.musicVolume,
                  onChanged: (v) {
                    setState(() => _settings!.musicVolume = v);
                    _settings!.save();
                  },
                ),
                const SizedBox(height: 20),
                _SliderSetting(
                  label: 'Efeitos Sonoros',
                  icon: Icons.volume_up,
                  value: _settings!.sfxVolume,
                  onChanged: (v) {
                    setState(() => _settings!.sfxVolume = v);
                    _settings!.save();
                  },
                ),
                const SizedBox(height: 40),
                _SectionHeader(label: '🎮 Sobre o Jogo'),
                const SizedBox(height: 16),
                _InfoCard(
                  rows: [
                    _InfoRow('🔫 Arma de Sal', 'Atira projéteis de sal. Duração ilimitada.'),
                    _InfoRow('⬜ Armadilha', 'Elimina até 5 lesmas ao contato.'),
                    _InfoRow('👁️ Olho Chorão', 'Chora sobre as lesmas por 15 segundos.'),
                    _InfoRow('🥬 Alface', '5 pontos de vida. Proteja-a a todo custo!'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 15)),
            const Spacer(),
            Text('${(value * 100).round()}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.greenAccent,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.greenAccent.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _InfoRow {
  final String label;
  final String desc;
  const _InfoRow(this.label, this.desc);
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.desc,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 13)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
