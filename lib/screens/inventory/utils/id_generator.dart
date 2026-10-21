String nextSequenceId({
  required String prefix,
  required Iterable<String> existingIds,
  int width = 4,
}) {
  int maxId = 0;
  for (final id in existingIds) {
    if (id.startsWith(prefix)) {
      final numPart = id.substring(prefix.length);
      final currentId = int.tryParse(numPart) ?? 0;
      if (currentId > maxId) {
        maxId = currentId;
      }
    }
  }
  final nextId = maxId + 1;
  return '$prefix${nextId.toString().padLeft(width, '0')}';
}
