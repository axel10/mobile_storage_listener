enum MobileStorageEventType {
  mounted,
  unmounted,
  removed,
  eject,
  badRemoval,
  unknown,
}

class MobileStorageEvent {
  const MobileStorageEvent({required this.type, required this.path});

  final MobileStorageEventType type;
  final String? path;

  factory MobileStorageEvent.fromMap(Map<Object?, Object?> map) {
    final typeName = map['type'] as String?;
    return MobileStorageEvent(
      type: _decodeType(typeName),
      path: map['path'] as String?,
    );
  }

  static MobileStorageEventType _decodeType(String? type) {
    return switch (type) {
      'mounted' => MobileStorageEventType.mounted,
      'unmounted' => MobileStorageEventType.unmounted,
      'removed' => MobileStorageEventType.removed,
      'eject' => MobileStorageEventType.eject,
      'bad_removal' => MobileStorageEventType.badRemoval,
      _ => MobileStorageEventType.unknown,
    };
  }

  String get typeName {
    return switch (type) {
      MobileStorageEventType.mounted => 'mounted',
      MobileStorageEventType.unmounted => 'unmounted',
      MobileStorageEventType.removed => 'removed',
      MobileStorageEventType.eject => 'eject',
      MobileStorageEventType.badRemoval => 'bad_removal',
      MobileStorageEventType.unknown => 'unknown',
    };
  }
}
