import 'package:bloomfx_shared/bloomfx_shared.dart';

/// COPY BLOOM `Deposit` / `user.js` finance list item.
class UserDeposit {
  final String id;
  final double amount;
  final String network;
  final String? walletAddress;
  final String status;
  final DateTime createdAt;
  /// 30-day lock expiry (set when admin approves / Paystack credits).
  final DateTime? expiresAt;
  /// Wallet address assignment countdown only (crypto pending); not deposit status.
  final DateTime? walletExpiresAt;
  final String? referrerCode;

  const UserDeposit({
    required this.id,
    required this.amount,
    required this.network,
    this.walletAddress,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.walletExpiresAt,
    this.referrerCode,
  });

  factory UserDeposit.fromJson(Map<String, dynamic> json) {
    return UserDeposit(
      id: json['id'].toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      network: json['network']?.toString() ?? '',
      walletAddress: json['walletAddress']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null,
      walletExpiresAt: json['walletExpiresAt'] != null
          ? DateTime.tryParse(json['walletExpiresAt'].toString())
          : null,
      referrerCode: json['referrerCode']?.toString(),
    );
  }

  UserDeposit copyWith({
    String? status,
    DateTime? expiresAt,
    DateTime? walletExpiresAt,
  }) {
    return UserDeposit(
      id: id,
      amount: amount,
      network: network,
      walletAddress: walletAddress,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      walletExpiresAt: walletExpiresAt ?? this.walletExpiresAt,
      referrerCode: referrerCode,
    );
  }
}

/// COPY BLOOM `Withdrawal` / `user.js` finance list item.
class UserWithdrawal {
  final String id;
  final double amount;
  final String network;
  final String walletAddress;
  final String status;
  final DateTime createdAt;
  final DateTime? processedAt;

  const UserWithdrawal({
    required this.id,
    required this.amount,
    required this.network,
    required this.walletAddress,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  factory UserWithdrawal.fromJson(Map<String, dynamic> json) {
    return UserWithdrawal(
      id: json['id'].toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      network: json['network']?.toString() ?? '',
      walletAddress: json['walletAddress']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      processedAt: json['processedAt'] != null ? DateTime.tryParse(json['processedAt'].toString()) : null,
    );
  }

  UserWithdrawal copyWith({
    String? status,
    DateTime? processedAt,
  }) {
    return UserWithdrawal(
      id: id,
      amount: amount,
      network: network,
      walletAddress: walletAddress,
      status: status ?? this.status,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}

class FinanceOverview {
  final double totalDeposits;
  final double pendingDeposits;
  final double totalWithdrawals;
  final double referralBonuses;
  final double dailyRewards;

  const FinanceOverview({
    this.totalDeposits = 0,
    this.pendingDeposits = 0,
    this.totalWithdrawals = 0,
    this.referralBonuses = 0,
    this.dailyRewards = 0,
  });

  factory FinanceOverview.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FinanceOverview();
    return FinanceOverview(
      totalDeposits: (json['totalDeposits'] as num?)?.toDouble() ?? 0,
      pendingDeposits: (json['pendingDeposits'] as num?)?.toDouble() ?? 0,
      totalWithdrawals: (json['totalWithdrawals'] as num?)?.toDouble() ?? 0,
      referralBonuses: (json['referralBonuses'] as num?)?.toDouble() ?? 0,
      dailyRewards: (json['dailyRewards'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Response of `GET /api/user/finance`.
class FinanceData {
  final Profile? profile;
  final FinanceOverview overview;
  final List<UserDeposit> deposits;
  final List<UserWithdrawal> withdrawals;
  final List<String> networks;
  final double minDeposit;
  final double minWithdrawal;

  const FinanceData({
    this.profile,
    this.overview = const FinanceOverview(),
    this.deposits = const [],
    this.withdrawals = const [],
    this.networks = const [],
    this.minDeposit = 7,
    this.minWithdrawal = 1.5,
  });

  factory FinanceData.fromJson(Map<String, dynamic> json, {String? userId}) {
    Profile? profile;
    final raw = json['profile'];
    if (raw is Map<String, dynamic>) {
      var p = Profile.fromJson(raw);
      if (p.userId.isEmpty && userId != null) p = p.copyWith(userId: userId);
      profile = p;
    } else if (raw is Map) {
      var p = Profile.fromJson(Map<String, dynamic>.from(raw));
      if (p.userId.isEmpty && userId != null) p = p.copyWith(userId: userId);
      profile = p;
    }

    return FinanceData(
      profile: profile,
      overview: FinanceOverview.fromJson(json['overview'] as Map<String, dynamic>?),
      deposits:
          (json['deposits'] as List<dynamic>?)
              ?.map((e) => UserDeposit.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      withdrawals:
          (json['withdrawals'] as List<dynamic>?)
              ?.map((e) => UserWithdrawal.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      networks:
          (json['networks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      minDeposit: (json['minDeposit'] as num?)?.toDouble() ?? 7,
      minWithdrawal: (json['minWithdrawal'] as num?)?.toDouble() ?? 1.5,
    );
  }
}
