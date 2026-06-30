import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/dashboard_snapshot.dart';
import 'atoms.dart';

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class CommandResultDialog extends StatelessWidget {
  const CommandResultDialog({
    required this.command,
    required this.commandId,
    required this.modeCode,
    required this.source,
    required this.createdBy,
    required this.createdAt,
    required this.commandStatus,
    required this.deviceStatus,
    required this.deviceMessage,
    required this.mqttTopic,
    required this.publishedAt,
    required this.acknowledgedAt,
    this.isIOS = false,
    super.key,
  });

  final String command;
  final String commandId;
  final String modeCode;
  final String source;
  final String createdBy;
  final String createdAt;
  final String commandStatus;
  final String deviceStatus;
  final String deviceMessage;
  final String mqttTopic;
  final String publishedAt;
  final String acknowledgedAt;
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    final (statusColor, _, statusText) = commandStatusStyle(deviceStatus);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultRow(
          label: 'Lệnh',
          value: '${commandLabel(command, modeCode: modeCode)} ($command)',
        ),
        _ResultRow(label: 'Mã lệnh', value: commandId),
        _ResultRow(label: 'Chế độ', value: modeCode),
        _ResultRow(label: 'Nguồn', value: source),
        _ResultRow(label: 'Người gửi', value: createdBy),
        _ResultRow(label: 'Trạng thái API', value: commandStatus),
        _ResultRow(label: 'Thiết bị', value: '$statusText ($deviceStatus)'),
        if (createdAt.isNotEmpty)
          _ResultRow(label: 'Tạo lúc', value: createdAt),
        if (publishedAt.isNotEmpty)
          _ResultRow(label: 'Đăng MQTT lúc', value: publishedAt),
        if (acknowledgedAt.isNotEmpty)
          _ResultRow(label: 'Xác nhận lúc', value: acknowledgedAt),
        if (mqttTopic.isNotEmpty)
          _ResultRow(label: 'Chủ đề MQTT', value: mqttTopic),
        if (deviceMessage.isNotEmpty)
          _ResultRow(
            label: 'Chi tiết',
            value: humanizeDeviceMessage(deviceMessage),
          ),
        const SizedBox(height: 8),
        Text(
          _statusHint(deviceStatus),
          style: TextStyle(fontSize: 12, color: statusColor),
        ),
      ],
    );
    final scrollableBody = SingleChildScrollView(child: body);
    if (isIOS) {
      return CupertinoAlertDialog(
        title: Text(_title(deviceStatus)),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: scrollableBody,
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Row(
        children: [
          Icon(_statusIcon(deviceStatus), color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_title(deviceStatus), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: scrollableBody,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  String _title(String deviceStatus) {
    return switch (deviceStatus) {
      'acknowledged' => 'Thiết bị đã áp dụng lệnh',
      'published' => 'Đã gửi lệnh lên MQTT',
      'publish_failed' => 'Gửi lệnh xuống thiết bị thất bại',
      'not_sent' => 'Lệnh bị từ chối',
      _ => 'Đã ghi nhận lệnh',
    };
  }

  String _statusHint(String deviceStatus) {
    return switch (deviceStatus) {
      'acknowledged' => 'ESP32/Wokwi đã xác nhận áp dụng lệnh này.',
      'published' => 'Bridge MQTT đã publish lệnh, đang chờ thiết bị ACK.',
      'publish_failed' =>
        'API vẫn nhận lệnh, nhưng bridge MQTT chưa gửi được xuống thiết bị.',
      'not_sent' => 'Lệnh bị backend chặn trước khi gửi xuống thiết bị.',
      _ => 'Lệnh đã được backend ghi nhận và đang chờ bridge MQTT xử lý.',
    };
  }

  IconData _statusIcon(String deviceStatus) {
    return switch (deviceStatus) {
      'acknowledged' => Icons.verified,
      'published' => Icons.upload_rounded,
      'publish_failed' || 'not_sent' => Icons.error_outline,
      _ => Icons.schedule_send,
    };
  }
}

enum DangerLevel {
  safe('An toàn', Icons.check_circle_outline, Color(0xFF1F7A5B),
      'Không cần xác nhận bổ sung.'),
  risky('Cần chú ý', Icons.warning_amber_rounded, Color(0xFFB26A00),
      'Một hướng sẽ bị chặn đèn xanh.'),
  critical('Nguy hiểm', Icons.dangerous_outlined, Color(0xFFC0392B),
      'Tất cả các hướng sẽ giữ đèn đỏ cho tới khi người vận hành đổi mode.');

  const DangerLevel(this.label, this.icon, this.color, this.description);

  final String label;
  final IconData icon;
  final Color color;
  final String description;

  static DangerLevel forMode(String modeCode) {
    return switch (modeCode) {
      'EMERGENCY' => DangerLevel.critical,
      'PRIORITY_NS' || 'PRIORITY_EW' => DangerLevel.risky,
      _ => DangerLevel.safe,
    };
  }
}

class DangerousCommandDialog extends StatelessWidget {
  const DangerousCommandDialog({
    required this.modeCode,
    required this.danger,
    this.isIOS = false,
    super.key,
  });

  final String modeCode;
  final DangerLevel danger;
  final bool isIOS;

  String get _impact {
    return switch (modeCode) {
      'PRIORITY_NS' => 'Hướng Bắc-Nam sẽ bị ép xanh, còn Đông-Tây giữ đỏ.',
      'PRIORITY_EW' => 'Hướng Đông-Tây sẽ bị ép xanh, còn Bắc-Nam giữ đỏ.',
      'EMERGENCY' => 'Tất cả các hướng sẽ giữ đỏ liên tục cho tới khi bạn '
          'chuyển về AUTO hoặc NIGHT.',
      _ => danger.description,
    };
  }

  @override
  Widget build(BuildContext context) {
    final command = 'SET_$modeCode';
    final title = 'Xác nhận ${commandLabel(command, modeCode: modeCode)}';
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mức độ rủi ro: ${danger.label}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: danger.color,
          ),
        ),
        const SizedBox(height: 12),
        Text(_impact),
        const SizedBox(height: 8),
        Text(
          'Mã lệnh: $command',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text(
          'Thiết bị sẽ nhận mode mới khi bridge MQTT gửi lệnh thành công.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
    if (isIOS) {
      return CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: content,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vẫn gửi'),
          ),
        ],
      );
    }
    return AlertDialog(
      icon: Icon(danger.icon, color: danger.color, size: 32),
      title: Text(title),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: danger.color,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.send),
          label: const Text('Vẫn gửi'),
        ),
      ],
    );
  }
}
