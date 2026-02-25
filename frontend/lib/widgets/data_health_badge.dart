import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/run_manifest_models.dart';
import '../providers/app_providers.dart';

class DataHealthBadge extends ConsumerWidget {
  final bool compact;

  const DataHealthBadge({super.key, this.compact = false});

  Color _statusColor(String status) {
    switch (status) {
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pass':
        return Icons.check_circle;
      case 'pass_with_warnings':
        return Icons.warning_amber_rounded;
      case 'fail':
        return Icons.error;
      default:
        return Icons.info_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pass':
        return 'pass';
      case 'pass_with_warnings':
        return 'warnings';
      case 'fail':
        return 'fail';
      default:
        return 'unknown';
    }
  }

  String _buildTooltipText(
    DataLoadState<FrontendHealthData>? healthState,
    DataLoadState<RunManifestPublic>? manifestState,
  ) {
    if (healthState == null ||
        healthState.isError ||
        healthState.data == null) {
      return 'Metadata no disponible';
    }

    final FrontendHealthData health = healthState.data!;
    final RunManifestPublic? manifest = manifestState?.data;
    final String generatedAt = manifest?.generatedAtUtc ?? '-';
    final int datasetCount = manifest?.datasetSummaries.length ?? 0;
    final String sources =
        manifest?.availableSources.join(', ') ?? 'sin fuentes';

    return 'quality: ${health.status}\n'
        'updated_at: $generatedAt\n'
        'sources: $sources (${health.availableSourcesCount}/3)\n'
        'datasets: $datasetCount\n'
        'degraded_mode: ${health.degradedMode}\n'
        'notes: ${health.message}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DataLoadState<FrontendHealthData>> healthAsync = ref.watch(
      frontendHealthProvider,
    );
    final AsyncValue<DataLoadState<RunManifestPublic>> manifestAsync = ref
        .watch(runManifestProvider);

    return healthAsync.when(
      loading: () => _buildChip(
        context,
        status: 'unknown',
        label: compact ? '...' : 'loading',
        sourcesCount: 0,
      ),
      error: (_, __) => _buildChip(
        context,
        status: 'unknown',
        label: compact ? 'unknown' : 'metadata unavailable',
        sourcesCount: 0,
      ),
      data: (DataLoadState<FrontendHealthData> healthState) {
        final FrontendHealthData? health = healthState.data;
        final String status = health?.status ?? 'unknown';
        final int sourcesCount = health?.availableSourcesCount ?? 0;
        final String label = _statusLabel(status);
        final DataLoadState<RunManifestPublic>? manifestState =
            manifestAsync.asData?.value;
        final String tooltip = _buildTooltipText(healthState, manifestState);

        return Tooltip(
          message: tooltip,
          child: Semantics(
            label:
                'Estado de datos $label, fuentes disponibles $sourcesCount de 3',
            child: _buildChip(
              context,
              status: status,
              label: label,
              sourcesCount: sourcesCount,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String status,
    required String label,
    required int sourcesCount,
  }) {
    final Color color = _statusColor(status);
    final IconData icon = _statusIcon(status);

    return Container(
      key: const Key('data-health-badge'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: compact ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Text(
            compact ? label : '$label | $sourcesCount/3',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
