import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String modeLabel(String modeCode) {
  return switch (modeCode) {
    'AUTO' => 'Tự động',
    'NIGHT' => 'Ban đêm',
    'PRIORITY_NS' => 'Ưu tiên Bắc-Nam',
    'PRIORITY_EW' => 'Ưu tiên Đông-Tây',
    'EMERGENCY' => 'Khẩn cấp',
    '' => '--',
    _ => modeCode,
  };
}

String phaseLabel(String phaseCode) {
  return switch (phaseCode) {
    'NS_GREEN' => 'Bắc-Nam xanh',
    'NS_YELLOW' => 'Bắc-Nam vàng',
    'EW_GREEN' => 'Đông-Tây xanh',
    'EW_YELLOW' => 'Đông-Tây vàng',
    'NS_PRIORITY' => 'Ưu tiên Bắc-Nam',
    'EW_PRIORITY' => 'Ưu tiên Đông-Tây',
    'YELLOW_BLINK' => 'Vàng nháy',
    'ALL_RED' => 'Tất cả đỏ',
    'NO_ACTIVE_PLAN' => 'Chưa có chu kỳ',
    '' => '--',
    _ => phaseCode,
  };
}

String commandLabel(String command, {String modeCode = ''}) {
  final mode = modeCode.isNotEmpty
      ? modeCode
      : command.toUpperCase().replaceFirst('SET_', '');
  return switch (mode) {
    'AUTO' => 'Bật chế độ tự động',
    'NIGHT' => 'Bật chế độ ban đêm',
    'PRIORITY_NS' => 'Ưu tiên hướng Bắc-Nam',
    'PRIORITY_EW' => 'Ưu tiên hướng Đông-Tây',
    'EMERGENCY' => 'Dừng khẩn cấp',
    _ => command,
  };
}

String? normalizeApiBase(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (trimmed.isEmpty ||
      uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return trimmed;
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<dynamic> asList(Object? value) => value is List ? value : <dynamic>[];

String text(Object? value, String fallback) {
  final result = value?.toString();
  return result == null || result.isEmpty ? fallback : result;
}

int number(Object? value, int fallback) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool boolean(Object? value, bool fallback) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

String compactTime(Object? value) {
  final raw = value?.toString() ?? '';
  return raw.replaceFirst('T', ' ').split('.').first;
}

String humanizeDeviceMessage(String raw) {
  return switch (raw.trim()) {
    'Published to MQTT broker' => 'Đã publish lên MQTT broker',
    'Device acknowledged command' => 'Thiết bị đã xác nhận lệnh',
    'Command accepted' => 'Backend đã ghi nhận lệnh',
    'Unsupported command' => 'Lệnh không được hỗ trợ',
    'Emergency mode only allows SET_AUTO, SET_NIGHT, or SET_EMERGENCY' =>
      'Khi đang EMERGENCY chỉ cho phép SET_AUTO, SET_NIGHT hoặc SET_EMERGENCY',
    'device applied' => 'Thiết bị đã áp dụng lệnh',
    _ => raw,
  };
}

class ApiClient {
  ApiClient(this.baseUrl, {this.maxAttempts = 3});

  final String baseUrl;
  final int maxAttempts;

  Future<Map<String, dynamic>> getJson(String path) => _send('GET', path);

  Future<Map<String, dynamic>> postJson(
          String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> putJson(
          String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body}) async {
    final normalizedBase = normalizeApiBase(baseUrl);
    if (normalizedBase == null) {
      throw ApiException(
        'Địa chỉ API không hợp lệ. Hãy nhập đầy đủ http:// hoặc https://',
      );
    }
    final uri = Uri.parse('$normalizedBase$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    final encodedBody = body == null ? null : jsonEncode(body);

    Object? lastError;
    final attempts = attemptsForMethod(method);
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = switch (method) {
          'POST' => await http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 5)),
          'PUT' => await http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 5)),
          _ => await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 5)),
        };
        // 4xx: client error, do not retry.
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return _decodeOrThrow(response);
        }
        // 2xx: success.
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _decodeOrThrow(response);
        }
        // 5xx or anything else: retryable.
        lastError = ApiException('HTTP ${response.statusCode}');
      } on http.ClientException {
        lastError = ApiException('Không kết nối được API $baseUrl');
      } on TimeoutException {
        lastError = ApiException('API timeout $baseUrl');
      } on FormatException {
        // Bad response payload: do not retry, surface immediately.
        throw ApiException('API trả về dữ liệu không hợp lệ');
      }
      if (attempt < attempts) {
        // Exponential backoff: 300ms, 600ms, 1200ms ...
        final delay = Duration(milliseconds: 300 * (1 << (attempt - 1)));
        await Future<void>.delayed(delay);
      }
    }
    throw lastError ??
        ApiException('API request failed after $attempts attempts');
  }

  int attemptsForMethod(String method) {
    return method.toUpperCase() == 'GET' ? maxAttempts : 1;
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      if (error is Map<String, dynamic> && error['message'] != null) {
        throw ApiException(error['message'].toString());
      }
      throw ApiException('HTTP ${response.statusCode}');
    }
    return decoded;
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DashboardSnapshot {
  DashboardSnapshot({
    required this.status,
    required this.approaches,
    required this.phasePlans,
    required this.commands,
    required this.logs,
    required this.modes,
    required this.deviceStatuses,
  });

  final TrafficStatus status;
  final List<Approach> approaches;
  final List<PhasePlan> phasePlans;
  final List<CommandEntry> commands;
  final List<TrafficLog> logs;
  final List<Map<String, dynamic>> modes;
  final List<Map<String, dynamic>> deviceStatuses;

  factory DashboardSnapshot.empty() => DashboardSnapshot(
        status: TrafficStatus.empty(),
        approaches: [],
        phasePlans: [],
        commands: [],
        logs: [],
        modes: [],
        deviceStatuses: [],
      );

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      status: TrafficStatus.fromJson(asMap(json['status'])),
      approaches: asList(json['approaches'])
          .map((item) => Approach.fromJson(asMap(item)))
          .toList(),
      phasePlans: asList(json['phasePlans'])
          .map((item) => PhasePlan.fromJson(asMap(item)))
          .toList(),
      commands: asList(json['commands'])
          .map((item) => CommandEntry.fromJson(asMap(item)))
          .toList(),
      logs: asList(json['logs'])
          .map((item) => TrafficLog.fromJson(asMap(item)))
          .toList(),
      modes: asList(json['modes']).map(asMap).toList(),
      deviceStatuses: asList(json['deviceStatuses']).map(asMap).toList(),
    );
  }

  DashboardSnapshot copyWith({TrafficStatus? status}) {
    return DashboardSnapshot(
      status: status ?? this.status,
      approaches: approaches,
      phasePlans: phasePlans,
      commands: commands,
      logs: logs,
      modes: modes,
      deviceStatuses: deviceStatuses,
    );
  }
}

class TrafficStatus {
  TrafficStatus({
    required this.modeCode,
    required this.phaseCode,
    required this.remainingSeconds,
    required this.signals,
  });

  final String modeCode;
  final String phaseCode;
  final int remainingSeconds;
  final List<SignalStatus> signals;

  factory TrafficStatus.empty() => TrafficStatus(
      modeCode: '', phaseCode: '', remainingSeconds: -1, signals: []);

  factory TrafficStatus.fromJson(Map<String, dynamic> json) {
    return TrafficStatus(
      modeCode: text(json['modeCode'] ?? json['mode_code'], ''),
      phaseCode: text(json['phaseCode'] ?? json['phase_code'], ''),
      remainingSeconds:
          number(json['remainingSeconds'] ?? json['remaining_seconds'], -1),
      signals: asList(json['signals'])
          .map((item) => SignalStatus.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class SignalStatus {
  SignalStatus(
      {required this.approach, required this.signal, required this.color});

  final String approach;
  final String signal;
  final String color;

  factory SignalStatus.fromJson(Map<String, dynamic> json) {
    return SignalStatus(
      approach: text(json['approach'] ?? json['Approach'], ''),
      signal: text(json['signal'] ?? json['Signal'], ''),
      color: text(json['color'] ?? json['Color'], 'OFF').toUpperCase(),
    );
  }
}

class Approach {
  Approach({
    required this.id,
    required this.code,
    required this.name,
    required this.displayOrder,
    required this.isActive,
    required this.signalCode,
    required this.redPin,
    required this.yellowPin,
    required this.greenPin,
  });

  final int id;
  final String code;
  final String name;
  final int displayOrder;
  final bool isActive;
  final String signalCode;
  final int redPin;
  final int yellowPin;
  final int greenPin;

  factory Approach.fromJson(Map<String, dynamic> json) {
    return Approach(
      id: number(json['id'], 0),
      code: text(json['code'], ''),
      name: text(json['name'], ''),
      displayOrder: number(json['display_order'] ?? json['displayOrder'], 0),
      isActive: boolean(json['is_active'] ?? json['isActive'], true),
      signalCode: text(json['signal_code'] ?? json['signalCode'], ''),
      redPin: number(json['red_pin'] ?? json['redPin'], -1),
      yellowPin: number(json['yellow_pin'] ?? json['yellowPin'], -1),
      greenPin: number(json['green_pin'] ?? json['greenPin'], -1),
    );
  }
}

class PhasePlan {
  PhasePlan(
      {required this.id,
      required this.name,
      required this.isActive,
      required this.steps});

  final int id;
  final String name;
  final bool isActive;
  final List<PhaseStep> steps;

  int get greenSeconds {
    final greenSteps =
        steps.where((step) => step.code.endsWith('_GREEN')).toList();
    return greenSteps.isEmpty ? 10 : greenSteps.first.durationSeconds;
  }

  int get yellowSeconds {
    final yellowSteps =
        steps.where((step) => step.code.endsWith('_YELLOW')).toList();
    return yellowSteps.isEmpty ? 3 : yellowSteps.first.durationSeconds;
  }

  factory PhasePlan.fromJson(Map<String, dynamic> json) {
    return PhasePlan(
      id: number(json['id'], 0),
      name: text(json['name'], 'Phase plan'),
      isActive: boolean(json['is_active'] ?? json['isActive'], false),
      steps: asList(json['steps'])
          .map((item) => PhaseStep.fromJson(asMap(item)))
          .toList(),
    );
  }
}

class PhaseStep {
  PhaseStep({required this.code, required this.durationSeconds});

  final String code;
  final int durationSeconds;

  factory PhaseStep.fromJson(Map<String, dynamic> json) {
    return PhaseStep(
      code: text(json['code'], ''),
      durationSeconds:
          number(json['duration_seconds'] ?? json['durationSeconds'], 0),
    );
  }
}

class CommandEntry {
  CommandEntry({
    required this.id,
    required this.command,
    required this.modeCode,
    required this.source,
    required this.createdBy,
    required this.commandStatus,
    required this.deviceStatus,
    required this.deviceMessage,
    required this.mqttTopic,
    required this.createdAt,
    required this.publishedAt,
    required this.acknowledgedAt,
  });

  final int id;
  final String command;
  final String modeCode;
  final String source;
  final String createdBy;
  final String commandStatus;
  final String deviceStatus;
  final String deviceMessage;
  final String mqttTopic;
  final String createdAt;
  final String publishedAt;
  final String acknowledgedAt;

  factory CommandEntry.fallback({
    required String command,
    required String modeCode,
    required String source,
    required String createdBy,
  }) {
    return CommandEntry(
      id: 0,
      command: command,
      modeCode: modeCode,
      source: source,
      createdBy: createdBy,
      commandStatus: 'success',
      deviceStatus: 'queued',
      deviceMessage:
          'Đã ghi nhận lệnh, đang chờ bridge MQTT gửi xuống thiết bị.',
      mqttTopic: '',
      createdAt: '',
      publishedAt: '',
      acknowledgedAt: '',
    );
  }

  factory CommandEntry.fromJson(Map<String, dynamic> json) {
    return CommandEntry(
      id: number(json['id'], 0),
      command: text(json['command'], ''),
      modeCode: text(json['mode_code'] ?? json['modeCode'], ''),
      source: text(json['source'], ''),
      createdBy: text(json['created_by'] ?? json['createdBy'], ''),
      commandStatus: text(json['status'], ''),
      deviceStatus: text(json['device_status'] ?? json['status'], ''),
      deviceMessage: text(json['device_message'] ?? json['deviceMessage'], ''),
      mqttTopic: text(json['mqtt_topic'] ?? json['mqttTopic'], ''),
      createdAt: compactTime(json['created_at']),
      publishedAt: compactTime(json['published_at']),
      acknowledgedAt: compactTime(json['acknowledged_at']),
    );
  }
}

class TrafficLog {
  TrafficLog({
    required this.modeCode,
    required this.phaseCode,
    required this.remainingSeconds,
    required this.createdAt,
  });

  final String modeCode;
  final String phaseCode;
  final int remainingSeconds;
  final String createdAt;

  factory TrafficLog.fromJson(Map<String, dynamic> json) {
    return TrafficLog(
      modeCode: text(json['mode_code'], ''),
      phaseCode: text(json['phase_code'], ''),
      remainingSeconds: number(json['remaining_seconds'], -1),
      createdAt: compactTime(json['created_at']),
    );
  }
}

const _configuredApiBase = String.fromEnvironment('API_BASE_URL');

String get defaultApiBase {
  if (_configuredApiBase.isNotEmpty) {
    return _configuredApiBase;
  }
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return 'http://127.0.0.1:8000';
  }
  return 'http://10.0.2.2:8000';
}

const String _apiBasePrefsKey = 'iot_traffic_light.api_base_url';
const String _skipConfirmPrefsKey = 'iot_traffic_light.skip_danger_confirm';

class SettingsStore {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsStore._(prefs);
  }

  String? readApiBase() {
    final raw = _prefs.getString(_apiBasePrefsKey);
    if (raw == null) {
      return null;
    }
    return normalizeApiBase(raw);
  }

  Future<void> writeApiBase(String value) async {
    final normalized = normalizeApiBase(value);
    if (normalized == null) {
      await _prefs.remove(_apiBasePrefsKey);
      return;
    }
    await _prefs.setString(_apiBasePrefsKey, normalized);
  }

  bool readSkipConfirm() => _prefs.getBool(_skipConfirmPrefsKey) ?? false;

  Future<void> writeSkipConfirm(bool value) async {
    if (value) {
      await _prefs.setBool(_skipConfirmPrefsKey, true);
    } else {
      await _prefs.remove(_skipConfirmPrefsKey);
    }
  }
}
