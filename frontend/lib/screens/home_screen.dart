import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/feature_flags.dart';
import '../models/data_load_state.dart';
import '../models/run_manifest_models.dart';
import '../models/trend_history_models.dart';
import '../providers/app_providers.dart';
import '../widgets/degraded_state_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titulo principal
          const Text(
            'Tech Trends 2025',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Análisis Integral de Tendencias Tecnológicas 2025',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 40),

          // KPIs principales con iconos oficiales
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildKpiCardFA(
                icon: FontAwesomeIcons.github,
                value: '1,000',
                label: 'Total Repos Analizados',
                color: Colors.blue,
              ),
              _buildKpiCardFA(
                icon: FontAwesomeIcons.stackOverflow,
                value: '33,085',
                label: 'Preguntas Procesadas',
                color: const Color(0xFFF48024), // StackOverflow orange
              ),
              _buildKpiCardFA(
                icon: FontAwesomeIcons.reddit,
                value: '500',
                label: 'Posts de Reddit',
                color: const Color(0xFFFF4500), // Reddit orange
              ),
            ],
          ),
          const SizedBox(height: 32),

          // KEY INSIGHTS SECTION
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6), // Gris claro
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    Icon(Icons.insights, color: Color(0xFF374151), size: 28),
                    Text(
                      'Key Insights',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Insight 1: Python (logo oficial)
                _buildImageInsight(
                  'assets/images/python_logo.png',
                  'Python domina GitHub y StackOverflow',
                  '#1 en repositorios (369) y líder en preguntas +15k',
                  const Color(0xFF3776AB), // Python blue
                ),
                const SizedBox(height: 12),
                // Insight 2: Angular (logo oficial)
                _buildImageInsight(
                  'assets/images/angular_logo.png',
                  'Angular lidera los frameworks frontend',
                  '4,051 commits en 2025 - más que React y Vue juntos',
                  const Color(0xFFDD0031), // Angular red
                ),
                const SizedBox(height: 12),
                // Insight 3: DeepSeek AI (logo oficial)
                _buildImageInsight(
                  'assets/images/deepseek_logo.png',
                  'AI/ML es el tema más caliente en Reddit',
                  '316 menciones - 5x más que el segundo lugar',
                  const Color(0xFF0EA5E9), // DeepSeek blue
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          const _RunManifestStatusCard(),

          const SizedBox(height: 20),

          const _TrendTemporalBridgeCard(),

          const SizedBox(height: 32),

          // Seccion Sobre el Dashboard
          const Text(
            'Sobre el Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildInfoCardFA(
                icon: FontAwesomeIcons.github,
                title: 'GitHub Data',
                description:
                    'Análisis de repositorios, lenguajes más populares y correlación entre stars y contribuidores',
                color: Colors.blue,
              ),
              _buildInfoCardFA(
                icon: FontAwesomeIcons.stackOverflow,
                title: 'StackOverflow Data',
                description:
                    'Madurez de tecnologías y evolución del interés en frameworks a lo largo del año',
                color: const Color(0xFFF48024),
              ),
              _buildInfoCardFA(
                icon: FontAwesomeIcons.reddit,
                title: 'Reddit Data',
                description:
                    'Sentimiento de la comunidad sobre frameworks backend y temas de discusión frecuentes',
                color: const Color(0xFFFF4500),
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Integrantes
          const Text(
            'Integrantes del Equipo',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTeamMemberFA(
            'Samir Caizapasto',
            'GitHub ETL & Dashboard',
            FontAwesomeIcons.github,
            Colors.blue,
          ),
          _buildTeamMemberFA(
            'Andrés Salinas',
            'StackOverflow ETL & Dashboard',
            FontAwesomeIcons.stackOverflow,
            const Color(0xFFF48024),
          ),
          _buildTeamMemberFA(
            'Mateo Mayorga',
            'Reddit ETL & Dashboard',
            FontAwesomeIcons.reddit,
            const Color(0xFFFF4500),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildKpiCardFA({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 32, color: Colors.white.withOpacity(0.9)),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCardFA({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMemberFA(
    String name,
    String role,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: FaIcon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  role,
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget con imagen de logo oficial
  Widget _buildImageInsight(
    String imagePath,
    String title,
    String description,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
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

class _RunManifestStatusCard extends ConsumerWidget {
  const _RunManifestStatusCard();

  Color _statusColor(
    String qualityStatus,
    DataLoadState<RunManifestPublic> state,
  ) {
    if (state.isError || state.data == null) {
      return const Color(0xFF6B7280);
    }
    switch (qualityStatus) {
      case 'pass':
        return const Color(0xFF15803D);
      case 'pass_with_warnings':
        return const Color(0xFFD97706);
      case 'fail':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(
    String qualityStatus,
    DataLoadState<RunManifestPublic> state,
  ) {
    if (state.isError || state.data == null) return 'Metadata no disponible';
    if (state.isDegraded) return 'Metadata parcial disponible';
    switch (qualityStatus) {
      case 'pass':
        return 'Quality gate: pass';
      case 'pass_with_warnings':
        return 'Quality gate: pass_with_warnings';
      case 'fail':
        return 'Quality gate: fail';
      default:
        return 'Quality gate: unknown';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestAsync = ref.watch(runManifestProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: manifestAsync.when(
        loading: () => const SizedBox(
          height: 56,
          child: Align(
            alignment: Alignment.centerLeft,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, stackTrace) => const Text(
          'Metadata no disponible',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        data: (state) {
          final manifest = state.data;
          final qualityStatus = manifest?.qualityGateStatus ?? 'unknown';
          final statusColor = _statusColor(qualityStatus, state);
          final statusLabel = _statusLabel(qualityStatus, state);
          final generatedAt = manifest?.generatedAtUtc ?? '-';
          final datasetCount = manifest?.datasetSummaries.length ?? 0;
          final availableSources =
              manifest?.availableSources ?? const <String>[];
          final degradedMode = manifest?.degradedMode ?? true;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Data metadata status',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                statusLabel,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 4),
              Text(
                'updated_at: $generatedAt | datasets: $datasetCount | sources: ${availableSources.join(", ")}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              if (state.message?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    state.message!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              if (degradedMode)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Modo degradado activo: algunas fuentes no estuvieron disponibles.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFD97706)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TrendTemporalBridgeCard extends ConsumerWidget {
  const _TrendTemporalBridgeCard();

  String _buildSourceLabel(String source) {
    switch (source) {
      case 'bridge_json':
        return 'Bridge JSON';
      case 'csv_fallback':
        return 'CSV fallback';
      default:
        return 'CSV';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(trendTemporalProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: trendAsync.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Text(
          'No se pudo cargar la vista temporal: $error',
          style: const TextStyle(color: Colors.red),
        ),
        data: (state) {
          final trendData = state.data;
          final source = trendData?.source ?? 'csv';
          final snapshotCount = trendData?.snapshotCount ?? 0;
          final items = trendData?.items ?? const <TrendTopEntry>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.timeline, color: Color(0xFF1F2937)),
                  const Text(
                    'Vista temporal de Trend Score',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_buildSourceLabel(source)} | snapshots: $snapshotCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                FeatureFlags.useHistoryBridgeJson
                    ? 'Modo bridge activo por feature flag'
                    : 'Modo bridge desactivado por feature flag (CSV por defecto)',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              if (state.message?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    state.message!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Text(
                  'No hay datos temporales disponibles.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                )
              else if (state.isDegraded)
                DegradedStateCard(
                  message:
                      state.message ??
                      'Modo degradado activo en la vista temporal.',
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in items)
                      Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${item.ranking} ${item.tecnologia}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Score: ${item.trendScore} | Fuentes: ${item.fuentes}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
