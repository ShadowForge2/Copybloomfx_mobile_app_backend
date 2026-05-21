import 'rank.dart';

class Profile {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String country;
  final String referralCode;
  final String? referrerId;
  final int totalReferrals;
  final int validReferrals;
  final double referralEarnings;
  final String avatarUrl;
  final String profilePicture;
  final double lockedBalance;
  final double withdrawableBalance;
  final int rankId;
  final Rank? rank;
  final DateTime? lastDailyRewardAt;
  final DateTime? lastDailyProfitAt;
  final DateTime? lastWithdrawalAt;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    this.id = '',
    this.userId = '',
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.country = '',
    this.referralCode = '',
    this.referrerId,
    this.totalReferrals = 0,
    this.validReferrals = 0,
    this.referralEarnings = 0,
    this.avatarUrl = '',
    this.profilePicture = '',
    this.lockedBalance = 0,
    this.withdrawableBalance = 0,
    this.rankId = 1,
    this.rank,
    this.lastDailyRewardAt,
    this.lastDailyProfitAt,
    this.lastWithdrawalAt,
    this.lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get totalBalance => lockedBalance + withdrawableBalance;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? json['first_name']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? json['last_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      referralCode: json['referralCode']?.toString() ?? json['referral_code']?.toString() ?? '',
      referrerId: json['referrerId']?.toString() ?? json['referred_by']?.toString(),
      totalReferrals: json['totalReferrals'] as int? ?? json['total_referrals'] as int? ?? 0,
      validReferrals: json['validReferrals'] as int? ?? json['valid_referrals'] as int? ?? 0,
      referralEarnings: (json['referralEarnings'] as num?)?.toDouble() ?? (json['referral_earnings'] as num?)?.toDouble() ?? 0,
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString() ?? '',
      profilePicture: json['profilePicture']?.toString() ?? json['profile_picture']?.toString() ?? '',
      lockedBalance: (json['lockedBalance'] as num?)?.toDouble() ?? (json['locked_balance'] as num?)?.toDouble() ?? 0,
      withdrawableBalance: (json['withdrawableBalance'] as num?)?.toDouble() ?? (json['withdrawable_balance'] as num?)?.toDouble() ?? 0,
      rankId: json['rankId'] as int? ?? json['rank_id'] as int? ?? 1,
      rank: json['rank'] != null ? Rank.fromJson(Map<String, dynamic>.from(json['rank'] as Map)) : null,
      lastDailyRewardAt: _parseDate(json['lastDailyRewardAt'] ?? json['last_daily_reward_at']),
      lastDailyProfitAt: _parseDate(json['lastDailyProfitAt'] ?? json['last_daily_profit_at']),
      lastWithdrawalAt: _parseDate(json['lastWithdrawalAt'] ?? json['last_withdrawal_at']),
      lastLoginAt: _parseDate(json['lastLoginAt'] ?? json['last_login_at']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']) ?? DateTime.now(),
    );
  }

  Profile copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
    String? referralCode,
    String? referrerId,
    int? totalReferrals,
    int? validReferrals,
    double? referralEarnings,
    String? avatarUrl,
    String? profilePicture,
    double? lockedBalance,
    double? withdrawableBalance,
    int? rankId,
    Rank? rank,
    DateTime? lastDailyRewardAt,
    DateTime? lastDailyProfitAt,
    DateTime? lastWithdrawalAt,
    DateTime? lastLoginAt,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      referralCode: referralCode ?? this.referralCode,
      referrerId: referrerId ?? this.referrerId,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      validReferrals: validReferrals ?? this.validReferrals,
      referralEarnings: referralEarnings ?? this.referralEarnings,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profilePicture: profilePicture ?? this.profilePicture,
      lockedBalance: lockedBalance ?? this.lockedBalance,
      withdrawableBalance: withdrawableBalance ?? this.withdrawableBalance,
      rankId: rankId ?? this.rankId,
      rank: rank ?? this.rank,
      lastDailyRewardAt: lastDailyRewardAt ?? this.lastDailyRewardAt,
      lastDailyProfitAt: lastDailyProfitAt ?? this.lastDailyProfitAt,
      lastWithdrawalAt: lastWithdrawalAt ?? this.lastWithdrawalAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
