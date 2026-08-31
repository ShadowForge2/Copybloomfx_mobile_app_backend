class AdminDeposit {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final double amount;
  final String network;
  final String? walletAddress;
  final String status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? walletExpiresAt;
  final bool isFlagged;
  final bool isBanned;
  final String? referrerCode;
  /// 'paid' = user tapped "I have made payment" (ready to verify);
  /// 'timeout' = wallet window lapsed without confirmation (still approvable).
  final String? paymentStatus;

  AdminDeposit({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.amount,
    required this.network,
    this.walletAddress,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.walletExpiresAt,
    this.isFlagged = false,
    this.isBanned = false,
    this.referrerCode,
    this.paymentStatus,
  });

  /// User tapped "I have made payment" — admin should verify promptly.
  bool get isReadyToVerify => paymentStatus == 'paid';

  /// Wallet payment window lapsed without the user confirming. Still pending,
  /// so the admin CAN approve if payment actually arrived (late).
  bool get isWalletTimeout => status == 'pending' && paymentStatus == 'timeout';

  factory AdminDeposit.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return AdminDeposit(
      id: json['id'].toString(),
      userId: user?['id']?.toString() ?? json['userId']?.toString() ?? '',
      userName: user != null
          ? (user['username']?.toString() ?? '${user['firstName'] ?? user['first_name'] ?? ''} ${user['lastName'] ?? user['last_name'] ?? ''}'.trim())
          : json['userName']?.toString() ?? '',
      userEmail: user?['email']?.toString() ?? json['userEmail']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      network: json['network']?.toString() ?? '',
      walletAddress: json['walletAddress']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null,
      walletExpiresAt: json['walletExpiresAt'] != null ? DateTime.tryParse(json['walletExpiresAt'].toString()) : null,
      isFlagged: user?['isFlagged'] as bool? ?? json['isFlagged'] as bool? ?? false,
      isBanned: user?['isBanned'] as bool? ?? json['isBanned'] as bool? ?? false,
      referrerCode: json['referrerCode']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
    );
  }

  AdminDeposit copyWith({String? status}) {
    return AdminDeposit(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      amount: amount,
      network: network,
      walletAddress: walletAddress,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      walletExpiresAt: walletExpiresAt,
      isFlagged: isFlagged,
      isBanned: isBanned,
      referrerCode: referrerCode,
      paymentStatus: paymentStatus,
    );
  }
}

class AdminWithdrawal {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final double amount;
  final String network;
  final String walletAddress;
  final String status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final bool isFlagged;
  final bool isBanned;

  AdminWithdrawal({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.amount,
    required this.network,
    required this.walletAddress,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.isFlagged = false,
    this.isBanned = false,
  });

  factory AdminWithdrawal.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return AdminWithdrawal(
      id: json['id'].toString(),
      userId: user?['id']?.toString() ?? json['userId']?.toString() ?? '',
      userName: user != null
          ? (user['username']?.toString() ?? '${user['firstName'] ?? user['first_name'] ?? ''} ${user['lastName'] ?? user['last_name'] ?? ''}'.trim())
          : json['userName']?.toString() ?? '',
      userEmail: user?['email']?.toString() ?? json['userEmail']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      network: json['network']?.toString() ?? '',
      walletAddress: json['walletAddress']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      processedAt: json['processedAt'] != null ? DateTime.tryParse(json['processedAt'].toString()) : null,
      isFlagged: user?['isFlagged'] as bool? ?? json['isFlagged'] as bool? ?? false,
      isBanned: user?['isBanned'] as bool? ?? json['isBanned'] as bool? ?? false,
    );
  }

  AdminWithdrawal copyWith({String? status, DateTime? processedAt}) {
    return AdminWithdrawal(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      amount: amount,
      network: network,
      walletAddress: walletAddress,
      status: status ?? this.status,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
      isFlagged: isFlagged,
      isBanned: isBanned,
    );
  }
}

class PromoCode {
  final String id;
  final String code;
  final double minDeposit;
  final double maxBonus;
  final DateTime? expiresAt;
  final int usageLimit;
  final int usedCount;
  final bool isActive;
  final DateTime createdAt;

  PromoCode({
    required this.id,
    required this.code,
    this.minDeposit = 0,
    this.maxBonus = 0,
    this.expiresAt,
    this.usageLimit = 0,
    this.usedCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory PromoCode.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    return PromoCode(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      minDeposit: (json['minDeposit'] as num?)?.toDouble() ?? (json['min_deposit'] as num?)?.toDouble() ?? (json['bonusMin'] as num?)?.toDouble() ?? 0,
      maxBonus: (json['maxBonus'] as num?)?.toDouble() ?? (json['max_bonus'] as num?)?.toDouble() ?? (json['bonusMax'] as num?)?.toDouble() ?? 0,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : json['expiration'] != null ? DateTime.tryParse(json['expiration'].toString()) : null,
      usageLimit: (json['usageLimit'] as num?)?.toInt() ?? (json['usage_limit'] as num?)?.toInt() ?? 0,
      usedCount: (json['usedCount'] as num?)?.toInt() ?? (json['used_count'] as num?)?.toInt() ?? (json['usageCount'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? (status == 'active'),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  PromoCode copyWith({bool? isActive, int? usedCount}) {
    return PromoCode(
      id: id,
      code: code,
      minDeposit: minDeposit,
      maxBonus: maxBonus,
      expiresAt: expiresAt,
      usageLimit: usageLimit,
      usedCount: usedCount ?? this.usedCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

class PromoRedemption {
  final String id;
  final String userId;
  final String userName;
  final String promoCode;
  final double bonusAmount;
  final DateTime createdAt;

  PromoRedemption({
    required this.id,
    required this.userId,
    required this.userName,
    required this.promoCode,
    required this.bonusAmount,
    required this.createdAt,
  });

  factory PromoRedemption.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return PromoRedemption(
      id: json['id'].toString(),
      userId: user?['id']?.toString() ?? json['userId']?.toString() ?? '',
      userName: user != null
          ? (user['username']?.toString() ?? '${user['firstName'] ?? user['first_name'] ?? ''} ${user['lastName'] ?? user['last_name'] ?? ''}'.trim())
          : (json['userName']?.toString() ?? json['username']?.toString() ?? ''),
      promoCode: json['promoCode']?.toString() ?? json['promo_code']?.toString() ?? json['code']?.toString() ?? '',
      bonusAmount: (json['bonusAmount'] as num?)?.toDouble() ?? (json['bonus_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class AdminDashboardStats {
  final int totalUsers;
  final int totalDeposits;
  final int totalWithdrawals;
  final int pendingDeposits;
  final int pendingWithdrawals;
  final double totalDepositAmount;
  final double totalWithdrawalAmount;
  final int flaggedUsers;
  final int bannedUsers;

  AdminDashboardStats({
    this.totalUsers = 0,
    this.totalDeposits = 0,
    this.totalWithdrawals = 0,
    this.pendingDeposits = 0,
    this.pendingWithdrawals = 0,
    this.totalDepositAmount = 0,
    this.totalWithdrawalAmount = 0,
    this.flaggedUsers = 0,
    this.bannedUsers = 0,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AdminDashboardStats();
    return AdminDashboardStats(
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? (json['total_users'] as num?)?.toInt() ?? 0,
      totalDeposits: (json['totalDeposits'] as num?)?.toInt() ?? (json['total_deposits'] as num?)?.toInt() ?? 0,
      totalWithdrawals: (json['totalWithdrawals'] as num?)?.toInt() ?? (json['total_withdrawals'] as num?)?.toInt() ?? 0,
      pendingDeposits: (json['pendingDeposits'] as num?)?.toInt() ?? (json['pending_deposits'] as num?)?.toInt() ?? 0,
      pendingWithdrawals: (json['pendingWithdrawals'] as num?)?.toInt() ?? (json['pending_withdrawals'] as num?)?.toInt() ?? 0,
      totalDepositAmount: (json['totalDepositAmount'] as num?)?.toDouble() ?? (json['total_deposit_amount'] as num?)?.toDouble() ?? 0,
      totalWithdrawalAmount: (json['totalWithdrawalAmount'] as num?)?.toDouble() ?? (json['total_withdrawal_amount'] as num?)?.toDouble() ?? 0,
      flaggedUsers: (json['flaggedUsers'] as num?)?.toInt() ?? (json['flagged_users'] as num?)?.toInt() ?? 0,
      bannedUsers: (json['bannedUsers'] as num?)?.toInt() ?? (json['banned_users'] as num?)?.toInt() ?? 0,
    );
  }
}
