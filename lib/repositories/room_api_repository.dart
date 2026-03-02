import 'dart:math';

import 'package:hive/hive.dart';
import 'package:solo_level_system/models/room_management_model.dart';

/// Abstraction for all Solo Leveling API interactions.
///
/// Current implementation is offline-first + mocked transport.
/// Later this should be backed by a real single API endpoint without
/// changing the UI/service call sites.
abstract class SoloLevelingApiRepository {
  // ---- Rooms API ----
  Future<void> upsertRoomAmbience({
    required String roomId,
    required RoomManagementModel ambience,
  });

  Future<void> recordRoomVisit(String roomId);

  Future<void> recordRoomStudySession({
    required String roomId,
    required int minutes,
  });

  Future<RoomPopularitySnapshot> getRoomPopularity(String roomId);

  Future<List<RoomPresenceUser>> getRoomPresence(String roomId);

  Future<List<RoomChatMessage>> getRoomChatMessages({
    required String roomId,
    int limit,
  });

  Future<void> sendRoomChatMessage({
    required String roomId,
    required String senderId,
    required String text,
  });

  Future<RoomAgentProgress> getRoomAgentProgress(String roomId);

  Future<void> addRoomAgentStudyInteraction({
    required String roomId,
    required int minutes,
  });

  /// Attempts to sync queued actions to remote.
  ///
  /// Mocked for now; returns number of processed outbox events.
  Future<int> syncPendingActions();
}

class MockOfflineFirstSoloLevelingApiRepository
    implements SoloLevelingApiRepository {
  static const String _statsBoxName = 'soloLevelingApi_roomPopularityCache';
  static const String _chatBoxName = 'soloLevelingApi_roomChatCache';
  static const String _agentBoxName = 'soloLevelingApi_roomAgentCache';
  static const String _ambienceBoxName = 'soloLevelingApi_roomAmbienceCache';
  static const String _outboxBoxName = 'soloLevelingApi_outbox';

  final Random _random = Random();

  /// Inject online status checker when wiring to app lifecycle later.
  final bool Function() isOnline;

  MockOfflineFirstSoloLevelingApiRepository({bool Function()? isOnline})
    : isOnline = isOnline ?? (() => false);

  Future<Box<dynamic>> _openDynamicBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(name);
  }

  @override
  Future<void> upsertRoomAmbience({
    required String roomId,
    required RoomManagementModel ambience,
  }) async {
    final cache = await _openDynamicBox(_ambienceBoxName);
    await cache.put(roomId, ambience.toMap());
    await _enqueue(
      RoomApiAction(
        type: RoomApiActionType.upsertAmbience,
        roomId: roomId,
        payload: ambience.toMap(),
      ),
    );
  }

  @override
  Future<void> recordRoomVisit(String roomId) async {
    final stats = await _readStats(roomId);
    final next = stats.copyWith(visitCount: stats.visitCount + 1);
    await _writeStats(next);
    await _enqueue(
      RoomApiAction(
        type: RoomApiActionType.recordVisit,
        roomId: roomId,
        payload: {'visitCount': 1},
      ),
    );
  }

  @override
  Future<void> recordRoomStudySession({
    required String roomId,
    required int minutes,
  }) async {
    final safeMinutes = minutes.clamp(0, 10000);
    final stats = await _readStats(roomId);
    final next = stats.copyWith(
      sessionsCompleted: stats.sessionsCompleted + 1,
      totalFocusMinutes: stats.totalFocusMinutes + safeMinutes,
    );
    await _writeStats(next);
    await _enqueue(
      RoomApiAction(
        type: RoomApiActionType.recordStudySession,
        roomId: roomId,
        payload: {'minutes': safeMinutes},
      ),
    );
  }

  @override
  Future<RoomPopularitySnapshot> getRoomPopularity(String roomId) {
    return _readStats(roomId);
  }

  @override
  Future<List<RoomPresenceUser>> getRoomPresence(String roomId) async {
    // Mocked presence. Keep deterministic-ish range for UI testing.
    final count = 1 + _random.nextInt(12);
    return List.generate(
      count,
      (index) => RoomPresenceUser(
        id: 'mock-user-$index',
        displayName: 'Student ${index + 1}',
      ),
    );
  }

  @override
  Future<List<RoomChatMessage>> getRoomChatMessages({
    required String roomId,
    int limit = 50,
  }) async {
    final box = await _openDynamicBox(_chatBoxName);
    final raw = box.get(roomId);
    if (raw is! List) return const [];
    final messages = raw.whereType<Map>().map(RoomChatMessage.fromMap).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (messages.length <= limit) return messages;
    return messages.sublist(messages.length - limit);
  }

  @override
  Future<void> sendRoomChatMessage({
    required String roomId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final message = RoomChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(999)}',
      roomId: roomId,
      senderId: senderId,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    final box = await _openDynamicBox(_chatBoxName);
    final existing = await getRoomChatMessages(roomId: roomId, limit: 1000);
    await box.put(roomId, [...existing.map((e) => e.toMap()), message.toMap()]);

    await _enqueue(
      RoomApiAction(
        type: RoomApiActionType.sendChatMessage,
        roomId: roomId,
        payload: message.toMap(),
      ),
    );
  }

  @override
  Future<RoomAgentProgress> getRoomAgentProgress(String roomId) async {
    final box = await _openDynamicBox(_agentBoxName);
    final raw = box.get(roomId);
    if (raw is Map) return RoomAgentProgress.fromMap(raw);
    return RoomAgentProgress(roomId: roomId);
  }

  @override
  Future<void> addRoomAgentStudyInteraction({
    required String roomId,
    required int minutes,
  }) async {
    final safeMinutes = minutes.clamp(0, 10000);
    final current = await getRoomAgentProgress(roomId);
    final gainedAffinity = max(1, safeMinutes ~/ 20);
    final next = current.copyWith(
      affinity: current.affinity + gainedAffinity,
      studyDays: current.studyDays + 1,
      lastInteractionAt: DateTime.now(),
    );

    final box = await _openDynamicBox(_agentBoxName);
    await box.put(roomId, next.toMap());

    await _enqueue(
      RoomApiAction(
        type: RoomApiActionType.addAgentInteraction,
        roomId: roomId,
        payload: {'minutes': safeMinutes, 'gainedAffinity': gainedAffinity},
      ),
    );
  }

  @override
  Future<int> syncPendingActions() async {
    if (!isOnline()) return 0;
    final outbox = await _openDynamicBox(_outboxBoxName);
    final actions =
        outbox.values.whereType<Map>().map(RoomApiAction.fromMap).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Mock success: clear all queued events.
    await outbox.clear();
    return actions.length;
  }

  Future<RoomPopularitySnapshot> _readStats(String roomId) async {
    final box = await _openDynamicBox(_statsBoxName);
    final raw = box.get(roomId);
    if (raw is Map) return RoomPopularitySnapshot.fromMap(raw);
    return RoomPopularitySnapshot(roomId: roomId);
  }

  Future<void> _writeStats(RoomPopularitySnapshot snapshot) async {
    final box = await _openDynamicBox(_statsBoxName);
    await box.put(snapshot.roomId, snapshot.toMap());
  }

  Future<void> _enqueue(RoomApiAction action) async {
    final box = await _openDynamicBox(_outboxBoxName);
    await box.add(action.toMap());
  }
}

/// Backward-compat aliases while migrating call sites.
typedef RoomApiRepository = SoloLevelingApiRepository;
typedef MockOfflineFirstRoomApiRepository =
    MockOfflineFirstSoloLevelingApiRepository;

enum RoomApiActionType {
  upsertAmbience,
  recordVisit,
  recordStudySession,
  sendChatMessage,
  addAgentInteraction,
}

class RoomApiAction {
  final RoomApiActionType type;
  final String roomId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  RoomApiAction({
    required this.type,
    required this.roomId,
    required this.payload,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'roomId': roomId,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RoomApiAction.fromMap(Map<dynamic, dynamic> map) {
    final typeName =
        map['type']?.toString() ?? RoomApiActionType.recordVisit.name;
    final matchedType = RoomApiActionType.values.firstWhere(
      (item) => item.name == typeName,
      orElse: () => RoomApiActionType.recordVisit,
    );
    return RoomApiAction(
      type: matchedType,
      roomId: map['roomId']?.toString() ?? '',
      payload: (map['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class RoomPopularitySnapshot {
  final String roomId;
  final int visitCount;
  final int sessionsCompleted;
  final int totalFocusMinutes;

  const RoomPopularitySnapshot({
    required this.roomId,
    this.visitCount = 0,
    this.sessionsCompleted = 0,
    this.totalFocusMinutes = 0,
  });

  RoomPopularitySnapshot copyWith({
    int? visitCount,
    int? sessionsCompleted,
    int? totalFocusMinutes,
  }) {
    return RoomPopularitySnapshot(
      roomId: roomId,
      visitCount: visitCount ?? this.visitCount,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
    );
  }

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'visitCount': visitCount,
    'sessionsCompleted': sessionsCompleted,
    'totalFocusMinutes': totalFocusMinutes,
  };

  factory RoomPopularitySnapshot.fromMap(Map<dynamic, dynamic> map) {
    return RoomPopularitySnapshot(
      roomId: map['roomId']?.toString() ?? '',
      visitCount: (map['visitCount'] as num?)?.toInt() ?? 0,
      sessionsCompleted: (map['sessionsCompleted'] as num?)?.toInt() ?? 0,
      totalFocusMinutes: (map['totalFocusMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class RoomPresenceUser {
  final String id;
  final String displayName;

  const RoomPresenceUser({required this.id, required this.displayName});

  Map<String, dynamic> toMap() => {'id': id, 'displayName': displayName};

  factory RoomPresenceUser.fromMap(Map<dynamic, dynamic> map) {
    return RoomPresenceUser(
      id: map['id']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
    );
  }
}

class RoomChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  const RoomChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'roomId': roomId,
    'senderId': senderId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RoomChatMessage.fromMap(Map<dynamic, dynamic> map) {
    return RoomChatMessage(
      id: map['id']?.toString() ?? '',
      roomId: map['roomId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class RoomAgentProgress {
  final String roomId;
  final int affinity;
  final int studyDays;
  final DateTime? lastInteractionAt;

  const RoomAgentProgress({
    required this.roomId,
    this.affinity = 0,
    this.studyDays = 0,
    this.lastInteractionAt,
  });

  RoomAgentProgress copyWith({
    int? affinity,
    int? studyDays,
    DateTime? lastInteractionAt,
  }) {
    return RoomAgentProgress(
      roomId: roomId,
      affinity: affinity ?? this.affinity,
      studyDays: studyDays ?? this.studyDays,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'affinity': affinity,
    'studyDays': studyDays,
    'lastInteractionAt': lastInteractionAt?.toIso8601String(),
  };

  factory RoomAgentProgress.fromMap(Map<dynamic, dynamic> map) {
    return RoomAgentProgress(
      roomId: map['roomId']?.toString() ?? '',
      affinity: (map['affinity'] as num?)?.toInt() ?? 0,
      studyDays: (map['studyDays'] as num?)?.toInt() ?? 0,
      lastInteractionAt: DateTime.tryParse(
        map['lastInteractionAt']?.toString() ?? '',
      ),
    );
  }
}
