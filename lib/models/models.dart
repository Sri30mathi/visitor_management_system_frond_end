// lib/models/models.dart

/// Parse an ISO 8601 string from the API and treat it as UTC so that
/// .toLocal() always converts correctly to the device's local timezone.
/// SQL Server / .NET sends datetimes without a 'Z' suffix — we add it.
DateTime _parseUtc(String s) {
  if (!s.endsWith('Z') && !s.contains('+') && !s.contains('-', 10)) {
    s = '${s}Z';
  }
  return DateTime.parse(s).toUtc();
}

DateTime? _parseUtcNullable(String? s) => s == null ? null : _parseUtc(s);

// ── Auth ──────────────────────────────────────────────────
class LoginResponse {
  final String accessToken;
  final String userId;
  final String fullName;
  final String role;
  final DateTime expiresAt;

  LoginResponse({
    required this.accessToken,
    required this.userId,
    required this.fullName,
    required this.role,
    required this.expiresAt,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
        accessToken: j['accessToken'],
        userId:      j['userId'],
        fullName:    j['fullName'],
        role:        j['role'],
        expiresAt:   _parseUtc(j['expiresAt']),
      );
}

class UserProfile {
  final String   userId;
  final String   fullName;
  final String   email;
  final String   role;
  final DateTime createdAt;

  UserProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        userId:    j['userId'],
        fullName:  j['fullName'],
        email:     j['email'],
        role:      j['role'],
        createdAt: _parseUtc(j['createdAt']),
      );
}

// ── Host ──────────────────────────────────────────────────
class HostDto {
  final String  hostId;
  final String  name;
  final String  email;
  final String? phone;
  final String  department;
  final bool    isActive;
  final int     totalVisitors;

  HostDto({
    required this.hostId,
    required this.name,
    required this.email,
    this.phone,
    required this.department,
    required this.isActive,
    required this.totalVisitors,
  });

  factory HostDto.fromJson(Map<String, dynamic> j) => HostDto(
        hostId:        j['hostId'],
        name:          j['name'],
        email:         j['email'],
        phone:         j['phone'],
        department:    j['department'],
        isActive:      j['isActive'],
        totalVisitors: j['totalVisitors'] ?? 0,
      );
}

// ── Visitor Entry (list) ──────────────────────────────────
class VisitorEntryDto {
  final String    entryId;
  final String    visitorName;
  final String    mobileMasked;
  final String?   emailMasked;
  final String?   company;
  final String    purpose;
  final String    hostId;
  final String    hostName;
  final String    hostDepartment;
  final DateTime  visitDateTime;
  final String    status;
  final String?   qrToken;
  final String?   idType;
  final String?   idNumber;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String?   remarks;
  final String?   photoUrl;
  final DateTime  createdAt;
  final int?      durationMinutes;

  VisitorEntryDto({
    required this.entryId,
    required this.visitorName,
    required this.mobileMasked,
    this.emailMasked,
    this.company,
    required this.purpose,
    required this.hostId,
    required this.hostName,
    required this.hostDepartment,
    required this.visitDateTime,
    required this.status,
    this.qrToken,
    this.idType,
    this.idNumber,
    this.checkInTime,
    this.checkOutTime,
    this.remarks,
    this.photoUrl,
    required this.createdAt,
    this.durationMinutes,
  });

  factory VisitorEntryDto.fromJson(Map<String, dynamic> j) => VisitorEntryDto(
        entryId:         j['entryId'],
        visitorName:     j['visitorName'],
        mobileMasked:    j['mobileMasked'],
        emailMasked:     j['emailMasked'],
        company:         j['company'],
        purpose:         j['purpose'],
        hostId:          j['hostId'],
        hostName:        j['hostName'],
        hostDepartment:  j['hostDepartment'],
        visitDateTime:   _parseUtc(j['visitDateTime']),
        status:          j['status'],
        qrToken:         j['qrToken'],
        idType:          j['idType'],
        idNumber:        j['idNumber'],
        checkInTime:     _parseUtcNullable(j['checkInTime']  as String?),
        checkOutTime:    _parseUtcNullable(j['checkOutTime'] as String?),
        remarks:         j['remarks'],
        photoUrl:        j['photoUrl'],
        createdAt:       _parseUtc(j['createdAt']),
        durationMinutes: j['durationMinutes'],
      );
}

// ── Visitor Entry Detail ──────────────────────────────────
class VisitEventDto {
  final String   eventId;
  final String   eventType;
  final DateTime eventTime;
  final String?  notes;

  VisitEventDto({
    required this.eventId,
    required this.eventType,
    required this.eventTime,
    this.notes,
  });

  factory VisitEventDto.fromJson(Map<String, dynamic> j) => VisitEventDto(
        eventId:   j['eventId'],
        eventType: j['eventType'],
        eventTime: _parseUtc(j['eventTime']),
        notes:     j['notes'],
      );
}

class VisitorEntryDetailDto extends VisitorEntryDto {
  final String?             mobile;
  final String?             email;
  final String?             hostPhone;
  final String?             hostEmail;
  final List<VisitEventDto> events;

  VisitorEntryDetailDto({
    required super.entryId,
    required super.visitorName,
    required super.mobileMasked,
    super.emailMasked,
    super.company,
    required super.purpose,
    required super.hostId,
    required super.hostName,
    required super.hostDepartment,
    required super.visitDateTime,
    required super.status,
    super.qrToken,
    super.idType,
    super.idNumber,
    super.checkInTime,
    super.checkOutTime,
    super.remarks,
    super.photoUrl,
    required super.createdAt,
    super.durationMinutes,
    this.mobile,
    this.email,
    this.hostPhone,
    this.hostEmail,
    required this.events,
  });

  factory VisitorEntryDetailDto.fromJson(Map<String, dynamic> j) =>
      VisitorEntryDetailDto(
        entryId:         j['entryId'],
        visitorName:     j['visitorName'],
        mobileMasked:    j['mobile'] ?? '',
        mobile:          j['mobile'],
        emailMasked:     j['email'],
        email:           j['email'],
        company:         j['company'],
        purpose:         j['purpose'],
        hostId:          j['hostId'],
        hostName:        j['hostName'],
        hostDepartment:  j['hostDepartment'],
        hostPhone:       j['hostPhone'],
        hostEmail:       j['hostEmail'],
        visitDateTime:   _parseUtc(j['visitDateTime']),
        status:          j['status'],
        qrToken:         j['qrToken'],
        idType:          j['idType'],
        idNumber:        j['idNumber'],
        checkInTime:     _parseUtcNullable(j['checkInTime']  as String?),
        checkOutTime:    _parseUtcNullable(j['checkOutTime'] as String?),
        remarks:         j['remarks'],
        photoUrl:        j['photoUrl'],
        createdAt:       _parseUtc(j['createdAt']),
        durationMinutes: j['durationMinutes'],
        events: (j['events'] as List? ?? [])
            .map((e) => VisitEventDto.fromJson(e))
            .toList(),
      );
}

// ── Paged Result ──────────────────────────────────────────
class PagedResult<T> {
  final List<T> items;
  final int     totalCount;
  final int     page;
  final int     pageSize;
  final int     totalPages;

  PagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}

// ── Dashboard ─────────────────────────────────────────────
class HourlyCount {
  final int hour;
  final int count;
  HourlyCount({required this.hour, required this.count});
  factory HourlyCount.fromJson(Map<String, dynamic> j) =>
      HourlyCount(hour: j['hour'], count: j['count']);
}

class TopHost {
  final String hostName;
  final String department;
  final int    count;
  TopHost({required this.hostName, required this.department, required this.count});
  factory TopHost.fromJson(Map<String, dynamic> j) =>
      TopHost(hostName: j['hostName'], department: j['department'], count: j['count']);
}

class PurposeCount {
  final String purpose;
  final int    count;
  PurposeCount({required this.purpose, required this.count});
  factory PurposeCount.fromJson(Map<String, dynamic> j) =>
      PurposeCount(purpose: j['purpose'], count: j['count']);
}

class DashboardStats {
  final int                totalToday;
  final int                registered;
  final int                checkedIn;
  final int                checkedOut;
  final int                totalThisMonth;
  final int                totalAllTime;
  final List<HourlyCount>  hourlyCounts;
  final List<TopHost>      topHosts;
  final List<PurposeCount> purposeCounts;

  DashboardStats({
    required this.totalToday,
    required this.registered,
    required this.checkedIn,
    required this.checkedOut,
    required this.totalThisMonth,
    required this.totalAllTime,
    required this.hourlyCounts,
    required this.topHosts,
    required this.purposeCounts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalToday:     j['totalToday'],
        registered:     j['registered'],
        checkedIn:      j['checkedIn'],
        checkedOut:     j['checkedOut'],
        totalThisMonth: j['totalThisMonth'] ?? 0,
        totalAllTime:   j['totalAllTime'],
        hourlyCounts:   (j['hourlyCounts']  as List? ?? []).map((e) => HourlyCount.fromJson(e)).toList(),
        topHosts:       (j['topHosts']      as List? ?? []).map((e) => TopHost.fromJson(e)).toList(),
        purposeCounts:  (j['purposeCounts'] as List? ?? []).map((e) => PurposeCount.fromJson(e)).toList(),
      );
}

// ── Check-in/out response ─────────────────────────────────
class CheckInOutResponse {
  final String   entryId;
  final String   visitorName;
  final String   status;
  final DateTime eventTime;
  final String   message;
  final int?     durationMinutes;

  CheckInOutResponse({
    required this.entryId,
    required this.visitorName,
    required this.status,
    required this.eventTime,
    required this.message,
    this.durationMinutes,
  });

  factory CheckInOutResponse.fromJson(Map<String, dynamic> j) =>
      CheckInOutResponse(
        entryId:         j['entryId'],
        visitorName:     j['visitorName'],
        status:          j['status'],
        eventTime:       _parseUtc(j['eventTime']),
        message:         j['message'],
        durationMinutes: j['durationMinutes'],
      );
}

// ── QR scan result (from /visitors/scan/{token}) ──────────
class QrScanResult {
  final String   entryId;
  final String   visitorName;
  final String?  company;
  final String   status;
  final String   hostName;
  final String   hostDepartment;
  final String   purpose;
  final DateTime visitDateTime;
  final bool     canCheckIn;
  final bool     canCheckOut;

  QrScanResult({
    required this.entryId,
    required this.visitorName,
    this.company,
    required this.status,
    required this.hostName,
    required this.hostDepartment,
    required this.purpose,
    required this.visitDateTime,
    required this.canCheckIn,
    required this.canCheckOut,
  });

  factory QrScanResult.fromJson(Map<String, dynamic> j) => QrScanResult(
        entryId:        j['entryId'].toString(),
        visitorName:    j['visitorName'],
        company:        j['company'],
        status:         j['status'],
        hostName:       j['hostName'],
        hostDepartment: j['hostDepartment'],
        purpose:        j['purpose'],
        visitDateTime:  _parseUtc(j['visitDateTime']),
        canCheckIn:     j['canCheckIn']  ?? false,
        canCheckOut:    j['canCheckOut'] ?? false,
      );
}

// ── Smart scan result (single-call lookup + auto action) ──
class SmartScanResult {
  final String   entryId;
  final String   visitorName;
  final String?  company;
  final String   status;
  final String   action;   // CheckedIn | CheckedOut | AlreadyOut | NotFound
  final String   message;
  final String   hostName;
  final String   hostDepartment;
  final String   purpose;
  final DateTime eventTime;
  final int?     durationMinutes;

  SmartScanResult({
    required this.entryId,
    required this.visitorName,
    this.company,
    required this.status,
    required this.action,
    required this.message,
    required this.hostName,
    required this.hostDepartment,
    required this.purpose,
    required this.eventTime,
    this.durationMinutes,
  });

  factory SmartScanResult.fromJson(Map<String, dynamic> j) => SmartScanResult(
        entryId:         j['entryId'].toString(),
        visitorName:     j['visitorName'],
        company:         j['company'],
        status:          j['status'],
        action:          j['action'],
        message:         j['message'],
        hostName:        j['hostName'],
        hostDepartment:  j['hostDepartment'],
        purpose:         j['purpose'],
        eventTime:       _parseUtc(j['eventTime']),
        durationMinutes: j['durationMinutes'],
      );

  bool get isCheckedIn  => action == 'CheckedIn';
  bool get isCheckedOut => action == 'CheckedOut';
  bool get isAlreadyOut => action == 'AlreadyOut';
}

// ── QR Code image response (/visitors/{id}/qrcode) ───────
class QrCodeResponse {
  final String entryId;
  final String qrToken;
  final String qrImageBase64; // clean base64 PNG, no line breaks

  QrCodeResponse({
    required this.entryId,
    required this.qrToken,
    required this.qrImageBase64,
  });

  factory QrCodeResponse.fromJson(Map<String, dynamic> j) => QrCodeResponse(
        entryId:       j['entryId'],
        qrToken:       j['qrToken'],
        qrImageBase64: (j['qrImageBase64'] as String).replaceAll(RegExp(r'\s+'), ''),
      );
}

// ── Active visit check (returning visitor) ─────────────────
class ActiveVisitResponse {
  final String   entryId;
  final String   visitorName;
  final String   mobile;
  final String?  company;
  final String   purpose;
  final String   hostName;
  final String   hostDepartment;
  final String   status;
  final DateTime visitDateTime;
  final DateTime? checkInTime;
  final String?  qrToken;
  final int      totalVisits;

  ActiveVisitResponse({
    required this.entryId,
    required this.visitorName,
    required this.mobile,
    this.company,
    required this.purpose,
    required this.hostName,
    required this.hostDepartment,
    required this.status,
    required this.visitDateTime,
    this.checkInTime,
    this.qrToken,
    required this.totalVisits,
  });

  factory ActiveVisitResponse.fromJson(Map<String, dynamic> j) =>
      ActiveVisitResponse(
        entryId:        j['entryId'],
        visitorName:    j['visitorName'],
        mobile:         j['mobile'],
        company:        j['company'],
        purpose:        j['purpose'],
        hostName:       j['hostName'],
        hostDepartment: j['hostDepartment'],
        status:         j['status'],
        visitDateTime:  _parseUtc(j['visitDateTime']),
        checkInTime:    _parseUtcNullable(j['checkInTime']),
        qrToken:        j['qrToken'],
        totalVisits:    j['totalVisits'] ?? 1,
      );
}

// ── Visit history item ──────────────────────────────────────
class VisitHistoryItem {
  final String   entryId;
  final String   purpose;
  final String   hostName;
  final String   hostDepartment;
  final String   status;
  final DateTime visitDateTime;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int?     durationMinutes;

  VisitHistoryItem({
    required this.entryId,
    required this.purpose,
    required this.hostName,
    required this.hostDepartment,
    required this.status,
    required this.visitDateTime,
    this.checkInTime,
    this.checkOutTime,
    this.durationMinutes,
  });

  factory VisitHistoryItem.fromJson(Map<String, dynamic> j) =>
      VisitHistoryItem(
        entryId:         j['entryId'],
        purpose:         j['purpose'],
        hostName:        j['hostName'],
        hostDepartment:  j['hostDepartment'],
        status:          j['status'],
        visitDateTime:   _parseUtc(j['visitDateTime']),
        checkInTime:     _parseUtcNullable(j['checkInTime']),
        checkOutTime:    _parseUtcNullable(j['checkOutTime']),
        durationMinutes: j['durationMinutes'],
      );
}