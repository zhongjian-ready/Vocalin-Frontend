import 'user.dart';

class Group {
  final int id;
  final String name;
  final String inviteCode;
  final List<User> members;
  final String? pinnedMessage;
  final DateTime? timerStartDate;
  final String? timerTitle;

  Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
    this.pinnedMessage,
    this.timerStartDate,
    this.timerTitle,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: (json['id'] ?? json['ID']) as int,
      name: json['name'] as String? ?? 'My Group',
      inviteCode: json['invite_code'] as String,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => User.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pinnedMessage: json['pinned_message'] as String?,
      timerStartDate: json['timer_start_date'] != null
          ? DateTime.tryParse(json['timer_start_date'] as String)
          : null,
      timerTitle: json['timer_title'] as String?,
    );
  }
  
  // Helper for UI compatibility
  DateTime get createdAt => timerStartDate ?? DateTime.now();
  String? get topMessage => pinnedMessage;
}
