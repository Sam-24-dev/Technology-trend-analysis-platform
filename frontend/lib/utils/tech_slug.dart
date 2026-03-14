String normalizeSlug(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final String lowered = trimmed.toLowerCase();
  if (lowered == 'ai/ml' || lowered == 'ia/machine learning' || lowered == 'ai ml') {
    return 'ai-ml';
  }
  if (lowered == 'c#') {
    return 'c-sharp';
  }
  if (lowered == 'c++') {
    return 'c-plus-plus';
  }

  final String normalized = lowered
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized;
}

String normalizeKey(String value) {
  String normalized = value.toLowerCase().trim();
  if (normalized.isEmpty) {
    return '';
  }
  normalized = normalized.replaceAll('c#', 'csharp');
  normalized = normalized.replaceAll('#', 'sharp');
  normalized = normalized.replaceAll('c-plus-plus', 'cplusplus');
  normalized = normalized.replaceAll('c++', 'cplusplus');
  normalized = normalized.replaceAll('++', 'plusplus');
  normalized = normalized.replaceAll('+', 'plus');
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  return normalized;
}
