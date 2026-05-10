int? _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }

  return null;
}

String? _parseString(dynamic value) {
  if (value is! String) {
    return null;
  }

  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

bool _parseBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  return false;
}

class NoteFolder {
  const NoteFolder({
    required this.id,
    required this.name,
    this.type,
    this.editable = false,
    this.deletable = false,
  });

  final int id;
  final String name;
  final String? type;
  final bool editable;
  final bool deletable;

  bool get isCustom => type?.trim().toLowerCase() == 'custom';

  factory NoteFolder.fromJson(Map<String, dynamic> json) {
    return NoteFolder(
      id: _parseInt(json['id'] ?? json['ID']) ?? 0,
      name: _parseString(json['name']) ?? '',
      type: _parseString(json['type']),
      editable: _parseBool(json['editable']),
      deletable: _parseBool(json['deletable']),
    );
  }
}
