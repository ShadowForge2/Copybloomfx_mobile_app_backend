import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/finance_models.dart';
import '../services/investment_logic.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardData {
  final Profile? profile;
  final List<CopyTrade> copyTrades;
  final List<PendingDeposit> pendingDeposits;
  final List<Rank> ranks;
  final bool canClaimDaily;
  final double dailyRewardAmount;
  final int copyTradesLimit;
  final double minDeposit;
  final double minWithdrawal;

  DashboardData({
    this.profile,
    this.copyTrades = const [],
    this.pendingDeposits = const [],
    this.ranks = const [],
    this.canClaimDaily = false,
    this.dailyRewardAmount = 0.1,
    this.copyTradesLimit = 1,
    this.minDeposit = 7.0,
    this.minWithdrawal = 10.0,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json, {String? userId}) {
    Profile? profile;
    final rawProfile = json['profile'];
    if (rawProfile is Map<String, dynamic>) {
      var p = Profile.fromJson(rawProfile);
      if (p.userId.isEmpty && userId != null) {
        p = p.copyWith(userId: userId);
      }
      profile = p;
    } else if (rawProfile is Map) {
      var p = Profile.fromJson(Map<String, dynamic>.from(rawProfile));
      if (p.userId.isEmpty && userId != null) {
        p = p.copyWith(userId: userId);
      }
      profile = p;
    }

    return DashboardData(
      profile: profile,
      copyTrades:
          (json['copyTrades'] as List<dynamic>?)
              ?.map(
                (t) => CopyTrade.fromJson(Map<String, dynamic>.from(t as Map)),
              )
              .toList() ??
          [],
      pendingDeposits:
          (json['pendingDeposits'] as List<dynamic>?)
              ?.map(
                (d) => PendingDeposit.fromJson(
                  Map<String, dynamic>.from(d as Map),
                ),
              )
              .toList() ??
          [],
      ranks:
          (json['ranks'] as List<dynamic>?)
              ?.map((r) => Rank.fromJson(Map<String, dynamic>.from(r as Map)))
              .toList() ??
          [],
      canClaimDaily: json['canClaimDaily'] as bool? ?? false,
      dailyRewardAmount: (json['dailyRewardAmount'] as num?)?.toDouble() ?? 0.1,
      copyTradesLimit: json['copyTradesLimit'] as int? ?? 1,
      minDeposit: (json['minDeposit'] as num?)?.toDouble() ?? 7.0,
      minWithdrawal: (json['minWithdrawal'] as num?)?.toDouble() ?? 10.0,
    );
  }
}

class CopyTrade {
  final String id;
  final String pair;
  final String action;
  final double amount;
  final double entryPrice;
  final double? currentPrice;
  final double? exitPrice;
  final double? profit;
  final String status; // 'pending' → 'active' → 'completed' | 'lost'
  final DateTime createdAt;
  final DateTime? closeAt;

  CopyTrade({
    required this.id,
    required this.pair,
    required this.action,
    required this.amount,
    required this.entryPrice,
    this.currentPrice,
    this.exitPrice,
    this.profit,
    required this.status,
    required this.createdAt,
    this.closeAt,
  });

  CopyTrade copyWith({
    double? currentPrice,
    double? exitPrice,
    double? profit,
    String? status,
    DateTime? closeAt,
  }) {
    return CopyTrade(
      id: id,
      pair: pair,
      action: action,
      amount: amount,
      entryPrice: entryPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      exitPrice: exitPrice ?? this.exitPrice,
      profit: profit ?? this.profit,
      status: status ?? this.status,
      createdAt: createdAt,
      closeAt: closeAt ?? this.closeAt,
    );
  }

  double get priceChangePct {
    final base = currentPrice ?? entryPrice;
    return ((base - entryPrice) / entryPrice) * 100;
  }

  String get directionLabel => action == 'buy' ? 'LONG ▲' : 'SHORT ▼';

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isDone => status == 'completed' || status == 'lost';

  Duration? get remaining {
    if (closeAt == null) return null;
    final d = closeAt!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  factory CopyTrade.fromJson(Map<String, dynamic> json) {
    return CopyTrade(
      id: json['id'].toString(),
      pair: json['pair']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      entryPrice: (json['entryPrice'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (json['currentPrice'] as num?)?.toDouble(),
      exitPrice: (json['exitPrice'] as num?)?.toDouble(),
      profit: (json['profit'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      closeAt: json['closeAt'] != null
          ? DateTime.tryParse(json['closeAt'].toString())
          : null,
    );
  }
}

class PendingDeposit {
  final String id;
  final double amount;
  final String network;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? walletAddress;
  final String status;

  PendingDeposit({
    required this.id,
    required this.amount,
    required this.network,
    required this.createdAt,
    this.expiresAt,
    this.walletAddress,
    this.status = 'pending',
  });

  factory PendingDeposit.fromJson(Map<String, dynamic> json) {
    return PendingDeposit(
      id: json['id'].toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      network: json['network']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      walletAddress: json['walletAddress']?.toString(),
      status: json['status']?.toString() ?? 'pending',
    );
  }

  String? getTimeRemaining() {
    if (expiresAt == null) return 'Awaiting admin review';

    final now = DateTime.now();
    if (expiresAt!.isBefore(now)) return 'Lock period ended';

    final duration = expiresAt!.difference(now);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    return '${days}d ${hours}h ${minutes}m';
  }
}

class DashboardProvider extends ChangeNotifier with WidgetsBindingObserver {
  bool _backgrounded = false;
  final ApiService _apiService;
  String get apiBaseUrl => _apiService.baseUrl;

  static const double MIN_DEPOSIT = 7.0;
  static const double MIN_WITHDRAWAL = 10.0;
  static const double DAILY_REWARD_AMOUNT = 0.1;
  static const List<String> PAIRS = [
    'BTC/USDT',
    'ETH/USDT',
    'SOL/USDT',
    'BNB/USDT',
    'XRP/USDT',
    'DOGE/USDT',
    'ADA/USDT',
    'AVAX/USDT',
  ];

  DashboardProvider(this._apiService) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgrounded = true;
      for (final t in _tradeTimers.values) {
        t.cancel();
      }
      _tradeTimers.clear();
    } else if (state == AppLifecycleState.resumed) {
      _backgrounded = false;
    }
  }

  static bool canClaimDailyFrom(Profile? profile) {
    if (profile == null) return false;
    final last = profile.lastDailyRewardAt;
    if (last == null) return true;
    return last.isBefore(DashboardProvider.midnightWAT());
  }

  /// Midnight West African Time (WAT = UTC+1) for daily reward & trade limit reset.
  static DateTime midnightWAT() {
    final now = DateTime.now().toUtc();
    final watOffset = const Duration(hours: 1);
    final nowWAT = now.add(watOffset);
    final todayWAT = DateTime.utc(nowWAT.year, nowWAT.month, nowWAT.day);
    return todayWAT.subtract(watOffset);
  }

  DashboardData? _data;
  bool _isLoading = true;
  bool _isSimulating = false;
  bool _isSubmittingDeposit = false;
  bool _isSubmittingPaystackDeposit = false;
  bool _isSubmittingWithdrawal = false;
  String? _errorMessage;
  String? _userId;
  final Set<String> _notifiedWithdrawalIds = {};
  bool _isFirstFinanceFetch = true;
  bool _isFirstDashboardFetch = true;

  Future<void> _loadSeenHistoryIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('seen_history_ids_$userId');
      if (list != null) {
        _seenHistoryIds.addAll(list);
      }
    } catch (_) {}
  }

  Future<void> _saveSeenHistoryIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('seen_history_ids_$userId', _seenHistoryIds.toList());
    } catch (_) {}
  }

  Future<void> _loadNotifiedWithdrawalIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('notified_withdrawal_ids_$userId');
      if (list != null) {
        _notifiedWithdrawalIds.addAll(list);
      }
    } catch (_) {}
  }

  Future<void> _saveNotifiedWithdrawalIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('notified_withdrawal_ids_$userId', _notifiedWithdrawalIds.toList());
    } catch (_) {}
  }

  static const Duration _tradeDuration = Duration(seconds: 35);
  static const Duration _profitTick = Duration(milliseconds: 500);
  final Map<String, Timer> _tradeTimers = {};
  final Map<String, double> _tradeTargetProfits = {};
  Timer? _serverPollTimer;
  double _serverWithdrawable = 0.0;
  final Set<String> _seenHistoryIds = {};

  void _startProfitProgression(
    CopyTrade trade,
    double targetProfit,
    void Function() onUpdate,
    void Function() onComplete,
  ) {
    _tradeTargetProfits[trade.id] = targetProfit;
    final totalTicks =
        _tradeDuration.inMilliseconds ~/ _profitTick.inMilliseconds;
    var tick = 0;
    final random = Random();

    _tradeTimers[trade.id]?.cancel();
    _tradeTimers[trade.id] = Timer.periodic(_profitTick, (timer) {
      tick++;
      final elapsedSec = tick * _profitTick.inMilliseconds / 1000.0;

      double currentProfit;
      if (elapsedSec <= 10) {
        currentProfit = 0;
      } else {
        final profitProgress = ((elapsedSec - 10) / 20).clamp(0.0, 1.0);
        final fluctuation = 0.95 + random.nextDouble() * 0.15;
        currentProfit = targetProfit * profitProgress * fluctuation;
      }

      _updateTradeProfit(trade.id, currentProfit);

      if (tick >= totalTicks) {
        timer.cancel();
        _tradeTimers.remove(trade.id);
        _tradeTargetProfits.remove(trade.id);
        _completeTrade(trade.id);
        onComplete();
      } else {
        onUpdate();
      }
    });
  }

  void _updateTradeProfit(String tradeId, double profit) {
    final updated = _data?.copyTrades.map((t) {
      if (t.id != tradeId) return t;
      return t.copyWith(profit: profit);
    }).toList();
    if (updated != null && _data != null) {
      // Recalculate transient withdrawable balance by adding current
      // in-flight profits of active trades to the server's base withdrawable.
      final currentProfits = updated
          .where((t) => !t.isDone)
          .fold<double>(0.0, (s, t) => s + (t.profit ?? 0.0));

      final baseProfile = _data!.profile!;
      final transientProfile = baseProfile.copyWith(
        withdrawableBalance: _serverWithdrawable + currentProfits,
      );

      _data = _reconcileRanks(
        DashboardData(
          profile: transientProfile,
          copyTrades: updated,
          pendingDeposits: _data!.pendingDeposits,
          ranks: _data!.ranks,
          canClaimDaily: _data!.canClaimDaily,
          dailyRewardAmount: _data!.dailyRewardAmount,
          copyTradesLimit: _data!.copyTradesLimit,
          minDeposit: _data!.minDeposit,
          minWithdrawal: _data!.minWithdrawal,
        ),
      );
    }
    notifyListeners();
  }

  void _completeTrade(String tradeId) {
    final idx = _data?.copyTrades.indexWhere((t) => t.id == tradeId);
    if (idx == null || idx < 0) return;
    final trade = _data!.copyTrades[idx];
    if (trade.isDone) return;

    final targetProfit = _tradeTargetProfits[tradeId] ?? (trade.profit ?? 0.01);
    final finalProfit = (targetProfit * 100).round() / 100.0;

    // When completing locally, treat the server base as having been increased
    // by the final profit and clear transient profit contributions.
    _serverWithdrawable = _serverWithdrawable + finalProfit;

    final seeds = _seedRanks;
    var profile = InvestmentLogic.withResolvedRank(_data!.profile!, seeds);
    profile = InvestmentLogic.withResolvedRank(
      profile.copyWith(withdrawableBalance: _serverWithdrawable),
      seeds,
    );

    final updated = _data!.copyTrades.map((t) {
      if (t.id != tradeId) return t;
      return t.copyWith(
        profit: finalProfit,
        status: 'completed',
        closeAt: DateTime.now(),
      );
    }).toList();

    _data = _reconcileRanks(
      DashboardData(
        profile: profile,
        copyTrades: updated,
        pendingDeposits: _data!.pendingDeposits,
        ranks: InvestmentLogic.ranksWithCurrentFlag(seeds, profile.rank?.id),
        canClaimDaily: canClaimDailyFrom(profile),
        dailyRewardAmount: _data!.dailyRewardAmount,
        copyTradesLimit:
            profile.rank?.copyTradesLimit ?? _data!.copyTradesLimit,
        minDeposit: _data!.minDeposit,
        minWithdrawal: _data!.minWithdrawal,
      ),
    );
    _rebuildLocalFinanceSnapshot();
    notifyListeners();
  }

  FinanceData? _financeData;
  final List<UserDeposit> _localDeposits = [];
  final List<UserWithdrawal> _localWithdrawals = [];
  int _localDepositSeq = 0;
  int _localWithdrawSeq = 0;
  DateTime? _localLastWithdrawalRequestAt;
  final List<DateTime> _copyTradeSimTimestamps = [];

  /// Midnight West African Time (WAT = UTC+1) for daily trade limit reset.
  static DateTime _midnightWAT() => midnightWAT();

  DashboardData? get data => _data;
  FinanceData? get finance => _financeData;

  bool get showAdminSimulationStrip => _isDevEnvironment;

  /// True when the API URL points to a remote/production backend (not local dev machine).
  bool get _useLocalOnly =>
      _apiService.baseUrl.contains('your-backend-api.com') ||
      _apiService.baseUrl.contains('10.0.2.2') ||
      _apiService.baseUrl.contains('127.0.0.1') ||
      _apiService.baseUrl.contains('localhost');

  /// True when running on a local dev machine (127.0.0.1 or localhost).
  bool get _isDevEnvironment =>
      _apiService.baseUrl.contains('127.0.0.1') ||
      _apiService.baseUrl.contains('localhost');

  bool get isLoading => _isLoading;
  bool get isSimulating => _isSimulating;
  String? get errorMessage => _errorMessage;

  bool get canClaimRankDailyProfit {
    final p = _data?.profile;
    if (p == null) return false;
    final synced = InvestmentLogic.withResolvedRank(p, _seedRanks);
    return InvestmentLogic.canClaimRankDailyProfitToday(synced) &&
        InvestmentLogic.rankForPrincipal(synced.lockedBalance, _seedRanks) !=
            null &&
        synced.lockedBalance > 0;
  }

  List<Rank> get _seedRanks => InvestmentLogic.defaultRanks();

  DashboardData _buildEmptyDashboard(String? userId) {
    final now = DateTime.now();
    var profile = Profile(
      id: '',
      userId: userId ?? '',
      lockedBalance: 0,
      withdrawableBalance: 0,
      createdAt: now,
      updatedAt: now,
    );

    final ranks = InvestmentLogic.ranksWithCurrentFlag(_seedRanks, null);

    return DashboardData(
      profile: profile,
      copyTrades: const [],
      pendingDeposits: const [],
      ranks: ranks,
      canClaimDaily: false,
      dailyRewardAmount: DAILY_REWARD_AMOUNT,
      copyTradesLimit: 1,
      minDeposit: MIN_DEPOSIT,
      minWithdrawal: MIN_WITHDRAWAL,
    );
  }

  DashboardData _buildLocalDashboard(String? userId) {
    final now = DateTime.now();
    var profile = Profile(
      id: '1',
      userId: userId ?? 'dev_user_123',
      rankId: 5,
      lockedBalance: 25000.0,
      withdrawableBalance: 13154.0,
      referralCode: 'DEV123',
      totalReferrals: 3,
      validReferrals: 2,
      referralEarnings: 120.50,
      lastDailyRewardAt: now.subtract(const Duration(hours: 25)),
      lastDailyProfitAt: now.subtract(const Duration(hours: 30)),
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );
    profile = InvestmentLogic.withResolvedRank(profile, _seedRanks);

    final ranks = InvestmentLogic.ranksWithCurrentFlag(
      _seedRanks,
      profile.rank?.id,
    );
    final limit = profile.rank?.copyTradesLimit ?? 1;

    return DashboardData(
      profile: profile,
      copyTrades: const [],
      pendingDeposits: const [],
      ranks: ranks,
      canClaimDaily: canClaimDailyFrom(profile),
      dailyRewardAmount: DAILY_REWARD_AMOUNT,
      copyTradesLimit: limit,
      minDeposit: MIN_DEPOSIT,
      minWithdrawal: MIN_WITHDRAWAL,
    );
  }

  Future<void> fetchDashboardData({
    String? userId,
    bool showLoading = true,
  }) async {
    // Clear data if userId has changed to prevent data bleed
    if (userId != null && _userId != null && userId != _userId) {
      clearData();
    }
    if (userId != null) _userId = userId;
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    } else {
      _errorMessage = null;
    }

    try {
      if (_useLocalOnly) {
        await Future.delayed(const Duration(milliseconds: 400));
        _expireApprovedDeposits();
        _data ??= _buildLocalDashboard(_userId ?? userId);
        if (_data != null) {
          // persist server/base withdrawable for transient calculations
          if (_data?.profile != null) {
            _serverWithdrawable = _data!.profile!.withdrawableBalance;
          }
          _data = _reconcileRanks(_data!);
        }
      } else {
        final token = await AuthService.getToken();
        final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
        final res = await api.getUserDashboard();
        if (res.success && res.data != null) {
          _data = DashboardData.fromJson(res.data!, userId: _userId ?? userId);
          
          final activeUserId = _userId ?? userId;
          if (_isFirstDashboardFetch && activeUserId != null) {
            await _loadSeenHistoryIds(activeUserId);
            // Auto-mark any existing completed copy trades as seen on the first fetch
            final historyIds = _data!.copyTrades
                .where((t) => t.isDone)
                .map((t) => t.id);
            _seenHistoryIds.addAll(historyIds);
            await _saveSeenHistoryIds(activeUserId);
            _isFirstDashboardFetch = false;
          }

          // persist server/base withdrawable for transient calculations
          if (_data?.profile != null) {
            _serverWithdrawable = _data!.profile!.withdrawableBalance;
          }
          // Remove seen IDs that no longer exist in history (keep set small)
          final currentHistoryIds = _data!.copyTrades
              .where((t) => t.isDone)
              .map((t) => t.id)
              .toSet();
          _seenHistoryIds.retainAll(currentHistoryIds);
          if (_data?.profile != null) {
            final synced = InvestmentLogic.withResolvedRank(
              _data!.profile!,
              _seedRanks,
            );
            _data = _replaceProfile(_data!, synced);
            _data = _reconcileRanks(_data!);
          }
          await fetchFinance();
        } else {
          _errorMessage = res.message.isNotEmpty
              ? res.message
              : 'Dashboard unavailable';
          if (_data == null) {
            _data = _buildEmptyDashboard(_userId ?? userId);
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load dashboard. Please try again.';
      if (_data == null) {
        _data = _buildEmptyDashboard(_userId ?? userId);
      }
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
    if (_useLocalOnly) {
      _expireApprovedDeposits();
      _rebuildLocalFinanceSnapshot();
    }

    // Start server poller if there are pending/open trades that need
    // authoritative closure detection.
    _startServerPollIfNeeded();
  }

  /// Mark all currently available history trades as viewed by the user.
  void markHistoryViewed() async {
    if (_data == null) return;
    final historyIds = _data!.copyTrades
        .where((t) => t.isDone)
        .map((t) => t.id);
    _seenHistoryIds.addAll(historyIds);
    notifyListeners();
    if (_userId != null) {
      await _saveSeenHistoryIds(_userId!);
    }
  }

  /// Number of completed trades the user hasn't viewed yet (client-side only).
  int get unseenHistoryCount {
    if (_data == null) return 0;
    final ids = _data!.copyTrades.where((t) => t.isDone).map((t) => t.id);
    return ids.where((id) => !_seenHistoryIds.contains(id)).length;
  }

  Future<void> fetchFinance() async {
    _errorMessage = null;
    try {
      if (_useLocalOnly) {
        await Future.delayed(const Duration(milliseconds: 200));
        _rebuildLocalFinanceSnapshot();
        notifyListeners();
        return;
      }
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.getUserFinance();
      if (res.success && res.data != null) {
        _financeData = FinanceData.fromJson(res.data!, userId: _userId);
        
        if (_userId != null) {
          await _loadNotifiedWithdrawalIds(_userId!);
        }
        final isFirstFetch = _isFirstFinanceFetch;
        _isFirstFinanceFetch = false;

        for (final w in _financeData!.withdrawals) {
          if (w.status == 'approved') {
            final added = _notifiedWithdrawalIds.add(w.id);
            if (added && !isFirstFetch) {
              NotificationService.instance.showWithdrawalDelivered(w.amount);
            }
          }
        }
        if (_userId != null) {
          await _saveNotifiedWithdrawalIds(_userId!);
        }

        if (_financeData?.profile != null && _data != null) {
          final merged = InvestmentLogic.withResolvedRank(
            _financeData!.profile!,
            _seedRanks,
          );
          // update server base withdrawable when finance payload arrives
          _serverWithdrawable = merged.withdrawableBalance;
          _data = _reconcileRanks(
            DashboardData(
              profile: merged,
              copyTrades: _data!.copyTrades,
              pendingDeposits: _data!.pendingDeposits,
              ranks: _data!.ranks,
              canClaimDaily: _data!.canClaimDaily,
              dailyRewardAmount: _data!.dailyRewardAmount,
              copyTradesLimit:
                  merged.rank?.copyTradesLimit ?? _data!.copyTradesLimit,
              minDeposit: _financeData!.minDeposit,
              minWithdrawal: _financeData!.minWithdrawal,
            ),
          );
        }
      } else {
        _errorMessage = res.message;
      }
    } catch (e) {
      _errorMessage = 'Failed to load finance data';
    } finally {
      notifyListeners();
    }
  }

  void _rebuildLocalFinanceSnapshot() {
    final overview = FinanceOverview(
      totalDeposits: _localDeposits
          .where((d) => d.status == 'approved')
          .fold<double>(0, (s, d) => s + d.amount),
      pendingDeposits: _localDeposits
          .where((d) => d.status == 'pending')
          .fold<double>(0, (s, d) => s + d.amount),
      totalWithdrawals: _localWithdrawals
          .where((w) => w.status == 'approved')
          .fold<double>(0, (s, w) => s + w.amount),
      referralBonuses: _data?.profile?.referralEarnings ?? 0,
      dailyRewards: 0,
    );
    _financeData = FinanceData(
      profile: _data?.profile,
      overview: overview,
      deposits: List<UserDeposit>.from(_localDeposits),
      withdrawals: List<UserWithdrawal>.from(_localWithdrawals),
      networks: InvestmentLogic.depositNetworks,
      minDeposit: MIN_DEPOSIT,
      minWithdrawal: MIN_WITHDRAWAL,
    );
  }

  void _expireApprovedDeposits() {
    final now = DateTime.now();
    var totalExpired = 0.0;
    for (var i = 0; i < _localDeposits.length; i++) {
      final d = _localDeposits[i];
      if (d.status == 'approved' &&
          d.expiresAt != null &&
          d.expiresAt!.isBefore(now)) {
        _localDeposits[i] = d.copyWith(status: 'expired');
        totalExpired += d.amount;
      }
    }
    if (totalExpired > 0 && _data?.profile != null) {
      final newLocked = (_data!.profile!.lockedBalance - totalExpired).clamp(
        0.0,
        double.infinity,
      );
      var profile = _data!.profile!.copyWith(lockedBalance: newLocked);
      profile = InvestmentLogic.withResolvedRank(profile, _seedRanks);
      _updateDataWithProfile(profile);
    }
  }

  /// COPY BLOOM `POST /deposits` — pending until admin approves (no locked credit yet).
  bool get isSubmittingDeposit => _isSubmittingDeposit;
  bool get isSubmittingPaystackDeposit => _isSubmittingPaystackDeposit;

  Future<UserDeposit?> submitDeposit({
    required double amount,
    required String network,
  }) async {
    if (_isSubmittingDeposit) return null;
    _isSubmittingDeposit = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (amount < MIN_DEPOSIT) {
        _errorMessage = 'Minimum deposit is \$$MIN_DEPOSIT';
        return null;
      }
      if (!InvestmentLogic.depositNetworks.contains(network)) {
        _errorMessage = 'Invalid network';
        return null;
      }

      if (_useLocalOnly) {
        _localDepositSeq += 1;
        final id = 'ld$_localDepositSeq';
        final wallet = InvestmentLogic.mockWalletForNetwork(network);
        final exp = DateTime.now().add(
          Duration(days: InvestmentLogic.lockDays),
        );
        final dep = UserDeposit(
          id: id,
          amount: amount,
          network: network,
          walletAddress: wallet,
          status: 'pending',
          createdAt: DateTime.now(),
          expiresAt: exp,
        );
        _localDeposits.insert(0, dep);
        if (_data != null) {
          _data = _reconcileRanks(_data!);
        }
        _rebuildLocalFinanceSnapshot();
        return dep;
      }

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.postUserDeposit(amount: amount, network: network);
      if (res.success && res.data != null) {
        final m = res.data!;
        final dep = UserDeposit(
          id: m['id'].toString(),
          amount: (m['amount'] as num?)?.toDouble() ?? amount,
          network: m['network']?.toString() ?? network,
          walletAddress: m['walletAddress']?.toString(),
          status: m['status']?.toString() ?? 'pending',
          createdAt:
              DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          expiresAt: m['expiresAt'] != null
              ? DateTime.tryParse(m['expiresAt'].toString())
              : null,
          walletExpiresAt: m['walletExpiresAt'] != null
              ? DateTime.tryParse(m['walletExpiresAt'].toString())
              : null,
        );
        final currentFinance = _financeData;
        if (currentFinance != null) {
          final newOverview = FinanceOverview(
            totalDeposits: currentFinance.overview.totalDeposits,
            pendingDeposits: currentFinance.overview.pendingDeposits + dep.amount,
            totalWithdrawals: currentFinance.overview.totalWithdrawals,
            referralBonuses: currentFinance.overview.referralBonuses,
            dailyRewards: currentFinance.overview.dailyRewards,
          );
          _financeData = FinanceData(
            profile: currentFinance.profile,
            overview: newOverview,
            deposits: [dep, ...currentFinance.deposits],
            withdrawals: currentFinance.withdrawals,
            networks: currentFinance.networks,
            minDeposit: currentFinance.minDeposit,
            minWithdrawal: currentFinance.minWithdrawal,
          );
          notifyListeners();
        }

        fetchDashboardData(userId: _userId, showLoading: false);
        fetchFinance();
        return dep;
      }
      _errorMessage = res.message;
      return null;
    } finally {
      _isSubmittingDeposit = false;
      notifyListeners();
    }
  }

  /// COPY BLOOM `POST /withdrawals` — withdrawable debited immediately; request pending for admin approval.
  bool get isSubmittingWithdrawal => _isSubmittingWithdrawal;

  Future<UserWithdrawal?> submitWithdrawal({
    required double amount,
    required String network,
    required String walletAddress,
    bool userIsFlagged = false,
  }) async {
    if (_isSubmittingWithdrawal) return null;
    _isSubmittingWithdrawal = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (userIsFlagged) {
        _errorMessage = 'Withdrawals disabled for flagged accounts';
        return null;
      }
      if (amount < MIN_WITHDRAWAL) {
        _errorMessage = 'Minimum withdrawal is \$$MIN_WITHDRAWAL';
        return null;
      }
      if (!InvestmentLogic.depositNetworks.contains(network)) {
        _errorMessage = 'Invalid network';
        return null;
      }
      if (walletAddress.trim().isEmpty) {
        _errorMessage = 'Wallet address required';
        return null;
      }

      if (_data?.profile == null) {
        _errorMessage = 'Profile not loaded';
        return null;
      }

      if (_useLocalOnly) {
        final wb = _data!.profile!.withdrawableBalance;
        if (amount > wb) {
          _errorMessage = 'Insufficient withdrawable balance';
          return null;
        }
        final last = _localLastWithdrawalRequestAt;
        if (last != null &&
            DateTime.now().difference(last) < const Duration(hours: 24)) {
          _errorMessage = 'One withdrawal per 24 hours';
          return null;
        }
        await Future.delayed(const Duration(milliseconds: 400));
        _localWithdrawSeq += 1;
        final id = 'lw$_localWithdrawSeq';
        final w = UserWithdrawal(
          id: id,
          amount: amount,
          network: network,
          walletAddress: walletAddress.trim(),
          status: 'pending',
          createdAt: DateTime.now(),
        );
        _localWithdrawals.insert(0, w);
        _localLastWithdrawalRequestAt = DateTime.now();
        final newProfile = _data!.profile!.copyWith(
          withdrawableBalance: wb - amount,
          lastWithdrawalAt: DateTime.now(),
        );
        _updateDataWithProfile(newProfile);
        _rebuildLocalFinanceSnapshot();
        return w;
      }

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final apiRes = await api.postUserWithdrawal(
        amount: amount,
        network: network,
        walletAddress: walletAddress.trim(),
      );
      if (apiRes.success && apiRes.data != null) {
        final m = apiRes.data!;
        _errorMessage = null;
        final w = UserWithdrawal(
          id: m['id'].toString(),
          amount: (m['amount'] as num?)?.toDouble() ?? amount,
          network: m['network']?.toString() ?? network,
          walletAddress: m['walletAddress']?.toString() ?? walletAddress,
          status: m['status']?.toString() ?? 'pending',
          createdAt:
              DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
              DateTime.now(),
        );
        final currentFinance = _financeData;
        if (currentFinance != null) {
          final newOverview = FinanceOverview(
            totalDeposits: currentFinance.overview.totalDeposits,
            pendingDeposits: currentFinance.overview.pendingDeposits,
            totalWithdrawals: currentFinance.overview.totalWithdrawals + w.amount,
            referralBonuses: currentFinance.overview.referralBonuses,
            dailyRewards: currentFinance.overview.dailyRewards,
          );
          _financeData = FinanceData(
            profile: currentFinance.profile,
            overview: newOverview,
            deposits: currentFinance.deposits,
            withdrawals: [w, ...currentFinance.withdrawals],
            networks: currentFinance.networks,
            minDeposit: currentFinance.minDeposit,
            minWithdrawal: currentFinance.minWithdrawal,
          );
          notifyListeners();
        }

        await fetchDashboardData(userId: _userId, showLoading: false);
        await fetchFinance();
        return w;
      }
      _errorMessage = apiRes.message.isNotEmpty
          ? apiRes.message
          : 'Withdrawal request may have failed. Check your transaction history.';
      return null;
    } finally {
      _isSubmittingWithdrawal = false;
      notifyListeners();
    }
  }

  /// Local demo: mirrors `POST /admin/deposits/:id/approve`.
  /// In dev mode connected to a backend, calls the admin API with dev bypass token.
  Future<bool> devApproveDeposit(String id) async {
    if (_data?.profile == null) return false;

    if (_useLocalOnly) {
      final i = _localDeposits.indexWhere(
        (d) => d.id == id && d.status == 'pending',
      );
      if (i < 0) return false;
      final dep = _localDeposits[i];
      _localDeposits[i] = dep.copyWith(status: 'approved');
      var profile = _data!.profile!;
      var locked = profile.lockedBalance + dep.amount;
      var earnings = profile.referralEarnings;
      final bonus = dep.amount * InvestmentLogic.referralPctOnApprovedDeposit;
      if (profile.referrerId != null && profile.referrerId!.isNotEmpty) {
        locked += bonus;
        earnings += bonus;
        _localDepositSeq += 1;
        _localDeposits.insert(0, UserDeposit(
          id: 'ld$_localDepositSeq',
          amount: bonus,
          network: 'Referral Bonus',
          status: 'approved',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(days: InvestmentLogic.lockDays)),
        ));
      }
      profile = profile.copyWith(
        lockedBalance: locked,
        referralEarnings: earnings,
      );
      profile = InvestmentLogic.withResolvedRank(profile, _seedRanks);
      _updateDataWithProfile(profile);
      _rebuildLocalFinanceSnapshot();
      notifyListeners();
      return true;
    }

    if (_isDevEnvironment) {
      try {
        await http
            .post(
              Uri.parse(
                '${_apiService.baseUrl}/api/admin/deposits/$id/approve',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer admin_demo_token',
              },
            )
            .timeout(const Duration(seconds: 10));
        await fetchDashboardData(userId: _userId, showLoading: false);
        await fetchFinance();
        return true;
      } catch (e) {
        _errorMessage = 'Operation failed. Please try again.';
        notifyListeners();
        return false;
      }
    }

    return false;
  }

  /// Local demo: mirrors `POST /admin/deposits/:id/reject`.
  Future<bool> devRejectDeposit(String id) async {
    if (_useLocalOnly) {
      final i = _localDeposits.indexWhere(
        (d) => d.id == id && d.status == 'pending',
      );
      if (i < 0) return false;
      _localDeposits[i] = _localDeposits[i].copyWith(status: 'rejected');
      if (_data != null) {
        _data = _reconcileRanks(_data!);
      }
      _rebuildLocalFinanceSnapshot();
      notifyListeners();
      return true;
    }

    if (_isDevEnvironment) {
      try {
        await http
            .post(
              Uri.parse('${_apiService.baseUrl}/api/admin/deposits/$id/reject'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer admin_demo_token',
              },
            )
            .timeout(const Duration(seconds: 10));
        await fetchDashboardData(userId: _userId, showLoading: false);
        await fetchFinance();
        return true;
      } catch (e) {
        _errorMessage = 'Operation failed. Please try again.';
        notifyListeners();
        return false;
      }
    }

    return false;
  }

  /// Local demo: mirrors `POST /admin/withdrawals/:id/approve`.
  Future<bool> devApproveWithdrawal(String id) async {
    if (_useLocalOnly) {
      final i = _localWithdrawals.indexWhere(
        (w) => w.id == id && w.status == 'pending',
      );
      if (i < 0) return false;
      _localWithdrawals[i] = _localWithdrawals[i].copyWith(
        status: 'approved',
        processedAt: DateTime.now(),
      );
      _rebuildLocalFinanceSnapshot();
      notifyListeners();
      return true;
    }

    if (_isDevEnvironment) {
      try {
        await http
            .post(
              Uri.parse(
                '${_apiService.baseUrl}/api/admin/withdrawals/$id/approve',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer admin_demo_token',
              },
            )
            .timeout(const Duration(seconds: 10));
        await fetchDashboardData(userId: _userId, showLoading: false);
        await fetchFinance();
        return true;
      } catch (e) {
        _errorMessage = 'Operation failed. Please try again.';
        notifyListeners();
        return false;
      }
    }

    return false;
  }

  /// Local demo: mirrors `POST /admin/withdrawals/:id/reject` (refunds withdrawable).
  Future<bool> devRejectWithdrawal(String id) async {
    if (_data?.profile == null) return false;

    if (_useLocalOnly) {
      final i = _localWithdrawals.indexWhere(
        (w) => w.id == id && w.status == 'pending',
      );
      if (i < 0) return false;
      final w = _localWithdrawals[i];
      _localWithdrawals[i] = w.copyWith(
        status: 'rejected',
        processedAt: DateTime.now(),
      );
      final refund = _data!.profile!.withdrawableBalance + w.amount;
      _updateDataWithProfile(
        _data!.profile!.copyWith(withdrawableBalance: refund),
      );
      _rebuildLocalFinanceSnapshot();
      notifyListeners();
      return true;
    }

    if (_isDevEnvironment) {
      try {
        await http
            .post(
              Uri.parse(
                '${_apiService.baseUrl}/api/admin/withdrawals/$id/reject',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer admin_demo_token',
              },
            )
            .timeout(const Duration(seconds: 10));
        await fetchDashboardData(userId: _userId, showLoading: false);
        await fetchFinance();
        return true;
      } catch (e) {
        _errorMessage = 'Operation failed. Please try again.';
        notifyListeners();
        return false;
      }
    }

    return false;
  }

  DashboardData _replaceProfile(DashboardData d, Profile p) {
    return DashboardData(
      profile: p,
      copyTrades: d.copyTrades,
      pendingDeposits: d.pendingDeposits,
      ranks: d.ranks,
      canClaimDaily: canClaimDailyFrom(p),
      dailyRewardAmount: d.dailyRewardAmount,
      copyTradesLimit: p.rank?.copyTradesLimit ?? d.copyTradesLimit,
      minDeposit: d.minDeposit,
      minWithdrawal: d.minWithdrawal,
    );
  }

  /// Align ladder `isCurrent` with resolved rank (API may use a different rule set).
  DashboardData _reconcileRanks(DashboardData d) {
    final p = d.profile;
    if (p == null) return d;
    final resolved = InvestmentLogic.rankForPrincipal(
      p.lockedBalance,
      _seedRanks,
    );
    final rid = resolved?.id ?? p.rankId;
    final ranks = d.ranks.isNotEmpty
        ? d.ranks.map((r) => r.copyWith(isCurrent: r.id == rid)).toList()
        : InvestmentLogic.ranksWithCurrentFlag(_seedRanks, rid);
    final limit =
        resolved?.copyTradesLimit ??
        p.rank?.copyTradesLimit ??
        d.copyTradesLimit;
    final pending = _useLocalOnly
        ? _localDeposits
              .where((e) => e.status == 'pending')
              .map(
                (e) => PendingDeposit(
                  id: e.id,
                  amount: e.amount,
                  network: e.network,
                  createdAt: e.createdAt,
                  expiresAt: e.expiresAt,
                  walletAddress: e.walletAddress,
                  status: e.status,
                ),
              )
              .toList()
        : d.pendingDeposits;
    return DashboardData(
      profile: InvestmentLogic.withResolvedRank(p, _seedRanks),
      copyTrades: d.copyTrades,
      pendingDeposits: pending,
      ranks: ranks,
      canClaimDaily: canClaimDailyFrom(p),
      dailyRewardAmount: d.dailyRewardAmount,
      copyTradesLimit: limit,
      minDeposit: d.minDeposit,
      minWithdrawal: d.minWithdrawal,
    );
  }

  /// Clear all cached data to prevent data bleed when switching users
  void clearData() {
    _data = null;
    _financeData = null;
    _userId = null;
    _errorMessage = null;
    _isLoading = false;
    _isSimulating = false;
    _serverWithdrawable = 0.0;
    _seenHistoryIds.clear();
    _notifiedWithdrawalIds.clear();
    _isFirstFinanceFetch = true;
    _isFirstDashboardFetch = true;
    _localDeposits.clear();
    _localWithdrawals.clear();
    _localDepositSeq = 0;
    _localWithdrawSeq = 0;
    _localLastWithdrawalRequestAt = null;
    _copyTradeSimTimestamps.clear();
    for (final t in _tradeTimers.values) {
      t.cancel();
    }
    _tradeTimers.clear();
    _tradeTargetProfits.clear();
    _serverPollTimer?.cancel();
    _serverPollTimer = null;
    notifyListeners();
  }

  Future<bool> claimDailyReward() async {
    try {
      if (_useLocalOnly) {
        await Future.delayed(const Duration(seconds: 1));
        if (_data?.profile != null) {
          final updatedProfile = _data!.profile!.copyWith(
            withdrawableBalance:
                _data!.profile!.withdrawableBalance + DAILY_REWARD_AMOUNT,
            lastDailyRewardAt: DateTime.now(),
          );
          _updateDataWithProfile(
            InvestmentLogic.withResolvedRank(updatedProfile, _seedRanks),
          );
        }
        notifyListeners();
        return true;
      }

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.postUserDailyReward();
      if (res.success && res.data != null && res.data!['profile'] != null) {
        final p = Profile.fromJson(
          Map<String, dynamic>.from(res.data!['profile'] as Map),
        );
        final merged = p.userId.isEmpty && _userId != null
            ? p.copyWith(userId: _userId!)
            : p;
        _updateDataWithProfile(
          InvestmentLogic.withResolvedRank(merged, _seedRanks),
        );
        notifyListeners();
        return true;
      }
      _errorMessage = res.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to claim daily reward. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Django-style `generate_daily_profit`: locked balance × rank %, once per local day.
  Future<bool> claimRankDailyProfit() async {
    try {
      if (_data?.profile == null) return false;
      final seeds = _seedRanks;
      var profile = _data!.profile!;
      profile = InvestmentLogic.withResolvedRank(profile, seeds);

      if (!InvestmentLogic.canClaimRankDailyProfitToday(profile)) {
        _errorMessage = 'Rank daily profit already claimed today';
        notifyListeners();
        return false;
      }

      final rank = InvestmentLogic.rankForPrincipal(
        profile.lockedBalance,
        seeds,
      );
      if (rank == null || profile.lockedBalance <= 0) {
        _errorMessage = 'Tradable balance required. Please make a deposit.';
        notifyListeners();
        return false;
      }

      final amount = InvestmentLogic.dailyProfitLockedOnly(profile, rank);
      if (amount <= 0) {
        _errorMessage = 'Calculated profit is zero';
        notifyListeners();
        return false;
      }

      if (_useLocalOnly) {
        await Future.delayed(const Duration(milliseconds: 500));
        final updated = InvestmentLogic.withResolvedRank(
          profile.copyWith(
            withdrawableBalance: profile.withdrawableBalance + amount,
            lastDailyProfitAt: DateTime.now(),
          ),
          seeds,
        );
        _updateDataWithProfile(updated);
        notifyListeners();
        return true;
      }

      _errorMessage = 'Rank daily profit is applied by the server on schedule.';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to claim rank profit. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<CopyTrade?> simulateCopyTrade() async {
    if (_isSimulating) return null;
    _isSimulating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!_useLocalOnly) {
        final token = await AuthService.getToken();
        final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
        final res = await api.postUserCopyTradeSimulate();
        if (res.success) {
          await fetchDashboardData(userId: _userId, showLoading: false);
          await fetchFinance();
          _isSimulating = false;
          notifyListeners();
          final trades = _data?.copyTrades ?? [];
          return trades.isNotEmpty ? trades.first : null;
        }
        _errorMessage = res.message;
        _isSimulating = false;
        notifyListeners();
        return null;
      }

      await Future.delayed(const Duration(seconds: 1));
      final seeds = _seedRanks;
      if (_data?.profile == null) {
        _isSimulating = false;
        notifyListeners();
        return null;
      }

      final profile = InvestmentLogic.withResolvedRank(_data!.profile!, seeds);

      if (profile.lockedBalance <= 0) {
        _errorMessage = 'Tradable balance required. Please make a deposit.';
        _isSimulating = false;
        notifyListeners();
        return null;
      }

      final rank = InvestmentLogic.rankForPrincipal(
        profile.totalBalance,
        seeds,
      );
      if (rank == null) {
        _errorMessage = 'Deposit to a rank band first.';
        _isSimulating = false;
        notifyListeners();
        return null;
      }

      final limit = rank.copyTradesLimit;
      final midnightWAT = _midnightWAT();
      _copyTradeSimTimestamps.removeWhere((t) => t.isBefore(midnightWAT));
      if (_copyTradeSimTimestamps.length >= limit) {
        _errorMessage =
            'Copy trade limit reached for your rank — $limit trade(s) per day (resets 12AM WAT).';
        _isSimulating = false;
        notifyListeners();
        return null;
      }

      _copyTradeSimTimestamps.add(DateTime.now());

      final dailyProfitPct = rank?.dailyProfitPct ?? 1.67;
      final potentialDailyProfit =
          profile.lockedBalance * (dailyProfitPct / 100.0);
      final targetProfit = (potentialDailyProfit / limit).clamp(
        0.01,
        double.infinity,
      );

      final random = Random();
      final pair = PAIRS[random.nextInt(PAIRS.length)];
      final action = random.nextBool() ? 'buy' : 'sell';
      final lotRatio = (profile.lockedBalance / 10000.0).clamp(0.0, 1.0);
      final lotSize = 0.01 + lotRatio * 0.49;

      final closeAt = DateTime.now().add(_tradeDuration);

      final newTrade = CopyTrade(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pair: pair,
        action: action,
        amount: (lotSize * 100).round() / 100.0,
        entryPrice: 0,
        currentPrice: 0,
        profit: 0,
        status: 'pending',
        createdAt: DateTime.now(),
        closeAt: closeAt,
      );

      _data = _reconcileRanks(
        DashboardData(
          profile: profile,
          copyTrades: [newTrade, ..._data!.copyTrades],
          pendingDeposits: _data!.pendingDeposits,
          ranks: InvestmentLogic.ranksWithCurrentFlag(seeds, profile.rank?.id),
          canClaimDaily: canClaimDailyFrom(profile),
          dailyRewardAmount: _data!.dailyRewardAmount,
          copyTradesLimit: rank.copyTradesLimit,
          minDeposit: _data!.minDeposit,
          minWithdrawal: _data!.minWithdrawal,
        ),
      );

      _isSimulating = false;
      notifyListeners();

      _startProfitProgression(newTrade, targetProfit, () {}, () {});

      return newTrade;
    } catch (e) {
      _errorMessage = 'Failed to place copy trade. Please try again.';
      _isSimulating = false;
      notifyListeners();
      return null;
    }
  }

  void _updateDataWithProfile(Profile profile) {
    final seeds = _seedRanks;
    final synced = InvestmentLogic.withResolvedRank(profile, seeds);
    final prev = _data;
    if (prev == null) return;
    _data = _reconcileRanks(
      DashboardData(
        profile: synced,
        copyTrades: prev.copyTrades,
        pendingDeposits: prev.pendingDeposits,
        ranks: InvestmentLogic.ranksWithCurrentFlag(seeds, synced.rank?.id),
        canClaimDaily: canClaimDailyFrom(synced),
        dailyRewardAmount: prev.dailyRewardAmount,
        copyTradesLimit: synced.rank?.copyTradesLimit ?? 1,
        minDeposit: prev.minDeposit,
        minWithdrawal: prev.minWithdrawal,
      ),
    );
  }

  /// Local Paystack deposit — simulates Paystack payment and credits locked balance directly.
  /// In production, launches Paystack checkout URL and returns reference for verification.
  Future<Map<String, dynamic>> submitPaystackDeposit({
    required double amount,
    String? email,
  }) async {
    if (_isSubmittingPaystackDeposit)
      return {'success': false, 'blocked': true};
    _isSubmittingPaystackDeposit = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (amount < MIN_DEPOSIT) {
        _errorMessage = 'Minimum deposit is \$$MIN_DEPOSIT';
        return {'success': false};
      }

      if (_useLocalOnly || _isDevEnvironment) {
        if (_data?.profile == null) return {'success': false};
        var profile = _data!.profile!;
        var locked = profile.lockedBalance + amount;
        var earnings = profile.referralEarnings;

        final bonus = amount * InvestmentLogic.referralPctOnApprovedDeposit;
        final hasReferrer = profile.referrerId != null && profile.referrerId!.isNotEmpty;
        if (hasReferrer) {
          locked += bonus;
          earnings += bonus;
        }

        _localDepositSeq += 1;
        _localDeposits.insert(0, UserDeposit(
          id: 'ld$_localDepositSeq',
          amount: amount,
          network: 'Paystack',
          status: 'approved',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(days: InvestmentLogic.lockDays)),
        ));
        if (hasReferrer) {
          _localDepositSeq += 1;
          _localDeposits.insert(0, UserDeposit(
            id: 'ld$_localDepositSeq',
            amount: bonus,
            network: 'Referral Bonus',
            status: 'approved',
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(Duration(days: InvestmentLogic.lockDays)),
          ));
        }

        profile = profile.copyWith(
          lockedBalance: locked,
          referralEarnings: earnings,
        );
        profile = InvestmentLogic.withResolvedRank(profile, _seedRanks);
        _updateDataWithProfile(profile);
        _rebuildLocalFinanceSnapshot();
        notifyListeners();
        return {'success': true};
      }

      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.postPaystackInitialize(amount: amount);
      if (res.success && res.data != null) {
        final reference = res.data!['reference']?.toString() ?? '';
        final authUrl = res.data!['authorization_url']?.toString() ?? '';
        if (reference.isNotEmpty && authUrl.isNotEmpty) {
          final uri = Uri.parse(authUrl);
          if (await canLaunchUrl(uri)) {
            launchUrl(uri, mode: LaunchMode.inAppWebView);
          }
          fetchDashboardData(userId: _userId, showLoading: false);
          fetchFinance();
          return {
            'success': true,
            'reference': reference,
            'authorization_url': authUrl,
          };
        }
      }
      _errorMessage = res.message;
      return {'success': false};
    } finally {
      _isSubmittingPaystackDeposit = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPaystackPayment(String reference) async {
    _errorMessage = null;
    try {
      final token = await AuthService.getToken();
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final verify = await api.postPaystackVerify(reference);
      if (verify.data?['status'] == 'success') {
        await fetchDashboardData(userId: _userId, showLoading: false);
        await fetchFinance();
        return true;
      }
      _errorMessage =
          verify.data?['message']?.toString() ??
          verify.message ??
          'Payment not yet confirmed. Try again.';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Payment verification failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> redeemPromo(String code) async {
    try {
      if (_useLocalOnly) {
        await Future.delayed(const Duration(seconds: 1));
        if (code.toUpperCase() == 'BLOOM100') {
          if (_data?.profile != null) {
            _localDepositSeq += 1;
            _localDeposits.insert(0, UserDeposit(
              id: 'ld$_localDepositSeq',
              amount: 100.0,
              network: 'Promo Code',
              status: 'approved',
              createdAt: DateTime.now(),
              expiresAt: DateTime.now().add(Duration(days: InvestmentLogic.lockDays)),
            ));
            final updatedProfile = _data!.profile!.copyWith(
              lockedBalance: _data!.profile!.lockedBalance + 100.0,
            );
            _updateDataWithProfile(updatedProfile);
            return true;
          }
        }
        return false;
      }

      final token = await AuthService.getToken();
      if (token == null) return false;
      final api = ApiService(baseUrl: _apiService.baseUrl, authToken: token);
      final res = await api.redeemPromo(code.toUpperCase());
      if (res.success && res.data != null) {
        if (res.data!['profile'] != null) {
          final p = Profile.fromJson(
            Map<String, dynamic>.from(res.data!['profile'] as Map),
          );
          final merged = p.userId.isEmpty && _userId != null
              ? p.copyWith(userId: _userId!)
              : p;
          _updateDataWithProfile(
            InvestmentLogic.withResolvedRank(merged, _seedRanks),
          );
        }
        notifyListeners();
        return true;
      }
      _errorMessage = res.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to redeem promo. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Estimated daily rank profit (locked × %) for UI — does not mutate balances.
  double? potentialRankDailyProfit() {
    final p = _data?.profile;
    if (p == null) return null;
    final rank = InvestmentLogic.rankForPrincipal(p.lockedBalance, _seedRanks);
    if (rank == null || p.lockedBalance <= 0) return null;
    return InvestmentLogic.dailyProfitLockedOnly(p, rank);
  }

  (Rank? current, Rank? next, double progressPct)? rankProgress() {
    final p = _data?.profile;
    if (p == null) return null;
    return InvestmentLogic.rankProgress(p, _seedRanks);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _startServerPollIfNeeded() {
    if (_useLocalOnly) return;
    // Already polling
    if (_serverPollTimer != null) return;
    final hasPending = _data?.copyTrades.any((t) => !t.isDone) ?? false;
    if (!hasPending) return;
    _serverPollTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      try {
        await fetchDashboardData(userId: _userId, showLoading: false);
        // stop if nothing pending anymore
        final stillPending = _data?.copyTrades.any((t) => !t.isDone) ?? false;
        if (!stillPending) _stopServerPollIfNeeded();
      } catch (_) {
        // ignore errors during polling
      }
    });
  }

  void _stopServerPollIfNeeded() {
    _serverPollTimer?.cancel();
    _serverPollTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _tradeTimers.values) {
      t.cancel();
    }
    _tradeTimers.clear();
    _stopServerPollIfNeeded();
    super.dispose();
  }
}
