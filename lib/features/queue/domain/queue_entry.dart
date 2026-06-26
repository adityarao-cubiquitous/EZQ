import '../../recommendation/domain/customer_preferences.dart';
import 'queue_status.dart';

class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.tokenNumber,
    required this.tokenCode,
    required this.businessDate,
    required this.customerName,
    required this.phone,
    required this.partySize,
    required this.partySizeBand,
    required this.status,
    required this.estimatedWaitMinutes,
    required this.queuePosition,
    required this.extensionUsed,
    required this.joinedAt,
    this.notes,
    this.customerId,
    this.sessionType = 'web_guest',
    this.appSource = 'web',
    this.assignedTableId,
    this.assignedTableNumber,
    this.reservedAt,
    this.onTheWayAt,
    this.seatedAt,
    this.skippedAt,
    this.cancelledAt,
    this.noShowAt,
    this.expiredAt,
    this.completedAt,
    this.completedPartySize,
    this.tableCycleStartAt,
    this.tableCycleEndAt,
    this.tableCycleSource,
    this.customerPreferences,
  });

  final String id;
  final int tokenNumber;
  final String tokenCode;
  final String businessDate;
  final String customerName;
  final String phone;
  final int partySize;
  final String partySizeBand;
  final String? notes;
  final String? customerId;
  final String sessionType;
  final String appSource;
  final QueueStatus status;
  final String? assignedTableId;
  final String? assignedTableNumber;
  final int estimatedWaitMinutes;
  final int queuePosition;
  final bool extensionUsed;
  final DateTime joinedAt;
  final DateTime? reservedAt;
  final DateTime? onTheWayAt;
  final DateTime? seatedAt;
  final DateTime? skippedAt;
  final DateTime? cancelledAt;
  final DateTime? noShowAt;
  final DateTime? expiredAt;
  final DateTime? completedAt;
  final int? completedPartySize;
  final DateTime? tableCycleStartAt;
  final DateTime? tableCycleEndAt;
  final String? tableCycleSource;
  final CustomerPreferences? customerPreferences;

  int waitingMinutesSince(DateTime now) =>
      now.difference(joinedAt).inMinutes.clamp(0, 24 * 60);

  factory QueueEntry.fromMap(String id, Map<String, dynamic> data) {
    DateTime? readDate(String key) {
      final value = data[key];
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value != null && value.runtimeType.toString() == 'Timestamp') {
        return (value as dynamic).toDate() as DateTime;
      }
      return null;
    }

    return QueueEntry(
      id: id,
      tokenNumber: data['tokenNumber'] as int? ?? 0,
      tokenCode: data['tokenCode'] as String? ?? 'Q00',
      businessDate: data['businessDate'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      partySize: data['partySize'] as int? ?? 1,
      partySizeBand: data['partySizeBand'] as String? ?? '1-2',
      notes: data['notes'] as String?,
      customerId: data['customerId'] as String?,
      sessionType: data['sessionType'] as String? ?? 'web_guest',
      appSource: data['appSource'] as String? ?? 'web',
      status: QueueStatus.fromWireName(data['status'] as String?),
      assignedTableId: data['assignedTableId'] as String?,
      assignedTableNumber: data['assignedTableNumber'] as String?,
      estimatedWaitMinutes: data['estimatedWaitMinutes'] as int? ?? 5,
      queuePosition: data['queuePosition'] as int? ?? 1,
      extensionUsed: data['extensionUsed'] as bool? ?? false,
      joinedAt: readDate('joinedAt') ?? readDate('createdAt') ?? DateTime.now(),
      reservedAt: readDate('reservedAt'),
      onTheWayAt: readDate('onTheWayAt'),
      seatedAt: readDate('seatedAt'),
      skippedAt: readDate('skippedAt'),
      cancelledAt: readDate('cancelledAt'),
      noShowAt: readDate('noShowAt'),
      expiredAt: readDate('expiredAt'),
      completedAt: readDate('completedAt'),
      completedPartySize: data['completedPartySize'] as int?,
      tableCycleStartAt: readDate('tableCycleStartAt'),
      tableCycleEndAt: readDate('tableCycleEndAt'),
      tableCycleSource: data['tableCycleSource'] as String?,
      customerPreferences: data['customerPreferences'] is Map<String, dynamic>
          ? CustomerPreferences.fromMap(
              data['customerPreferences'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'tokenNumber': tokenNumber,
    'tokenCode': tokenCode,
    'businessDate': businessDate,
    'customerName': customerName,
    'phone': phone,
    'partySize': partySize,
    'partySizeBand': partySizeBand,
    'notes': notes,
    'customerId': customerId,
    'sessionType': sessionType,
    'appSource': appSource,
    'status': status.wireName,
    'assignedTableId': assignedTableId,
    'assignedTableNumber': assignedTableNumber,
    'estimatedWaitMinutes': estimatedWaitMinutes,
    'queuePosition': queuePosition,
    'extensionUsed': extensionUsed,
    'joinedAt': joinedAt.toIso8601String(),
    'reservedAt': reservedAt?.toIso8601String(),
    'onTheWayAt': onTheWayAt?.toIso8601String(),
    'seatedAt': seatedAt?.toIso8601String(),
    'skippedAt': skippedAt?.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
    'noShowAt': noShowAt?.toIso8601String(),
    'expiredAt': expiredAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'completedPartySize': completedPartySize,
    'tableCycleStartAt': tableCycleStartAt?.toIso8601String(),
    'tableCycleEndAt': tableCycleEndAt?.toIso8601String(),
    'tableCycleSource': tableCycleSource,
    'customerPreferences': customerPreferences?.toMap(),
  };

  QueueEntry copyWith({
    QueueStatus? status,
    int? queuePosition,
    int? estimatedWaitMinutes,
    String? assignedTableId,
    String? assignedTableNumber,
  }) {
    return QueueEntry(
      id: id,
      tokenNumber: tokenNumber,
      tokenCode: tokenCode,
      businessDate: businessDate,
      customerName: customerName,
      phone: phone,
      partySize: partySize,
      partySizeBand: partySizeBand,
      status: status ?? this.status,
      estimatedWaitMinutes: estimatedWaitMinutes ?? this.estimatedWaitMinutes,
      queuePosition: queuePosition ?? this.queuePosition,
      extensionUsed: extensionUsed,
      joinedAt: joinedAt,
      notes: notes,
      customerId: customerId,
      sessionType: sessionType,
      appSource: appSource,
      assignedTableId: assignedTableId ?? this.assignedTableId,
      assignedTableNumber: assignedTableNumber ?? this.assignedTableNumber,
      reservedAt: reservedAt,
      onTheWayAt: onTheWayAt,
      seatedAt: seatedAt,
      skippedAt: skippedAt,
      cancelledAt: cancelledAt,
      noShowAt: noShowAt,
      expiredAt: expiredAt,
      completedAt: completedAt,
      completedPartySize: completedPartySize,
      tableCycleStartAt: tableCycleStartAt,
      tableCycleEndAt: tableCycleEndAt,
      tableCycleSource: tableCycleSource,
      customerPreferences: customerPreferences,
    );
  }
}

int compareQueueEntriesByFifo(QueueEntry a, QueueEntry b) {
  final joinedAt = a.joinedAt.compareTo(b.joinedAt);
  if (joinedAt != 0) return joinedAt;

  final tokenNumber = a.tokenNumber.compareTo(b.tokenNumber);
  if (tokenNumber != 0) return tokenNumber;

  final queuePosition = a.queuePosition.compareTo(b.queuePosition);
  if (queuePosition != 0) return queuePosition;

  final tokenCode = a.tokenCode.compareTo(b.tokenCode);
  if (tokenCode != 0) return tokenCode;

  return a.id.compareTo(b.id);
}
