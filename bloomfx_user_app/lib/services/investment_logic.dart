import 'package:bloomfx_shared/bloomfx_shared.dart';

/// Business rules aligned with `COPY BLOOM INVESTMENT DATABASE` (Django + Node seed).
class InvestmentLogic {
  InvestmentLogic._();

  /// COPY BLOOM `server/src/utils/wallets.js` — must match server for `POST /deposits`.
  static const List<String> depositNetworks = [
    'USDT BEP20',
    'USDT ERC20',
    'BTC',
    'Solana',
    'Ethereum',
    'BNB SmartChain',
  ];

  /// `REFERRAL_PCT` in Node `user.js` / `admin.js`
  static const double referralPctOnApprovedDeposit = 0.08;

  /// Approved deposit lock period (must match backend `LOCK_DAYS`).
  static const int lockDays = 30;

  /// Crypto wallet address reservation window (UI only; deposit stays pending until admin).
  static const int walletAssignmentMinutes = 5;

  static const double openEndedMaxBalance = 999999.0;

  /// Matches Django wallet pool (first address per network).
  static String mockWalletForNetwork(String network) {
    const map = {
      'USDT BEP20': '0x330901bc8ccf6476cb6a007306a5d2956c62332f',
      'USDT ERC20': '0x330901Bc8CCf6476CB6a007306a5d2956c62332F',
      'BTC': 'bc1qr5mhdam324pxlme0dst953gq4lfj90ad6fzr5a',
      'Solana': '2nGvFch9BGccSe3Xi8Pj7YuMti17dtWBaaeEJJrHoyhh',
      'Ethereum': '0x330901bc8ccf6476cb6a007306a5d2956c62332f',
      'BNB SmartChain': '0x330901bc8ccf6476cb6a007306a5d2956c62332f',
    };
    return map[network] ?? '0x330901bc8ccf6476cb6a007306a5d2956c62332f';
  }

  /// Same six ranks as `server/src/seed.js` / `seed_ranks.py`.
  static List<Rank> defaultRanks() {
    return [
      Rank(
        id: 1,
        name: 'Green Horn',
        minBalance: 7,
        maxBalance: 49,
        dailyProfitPct: 1.67,
        copyTradesLimit: 1,
        color: '#4CAF50',
      ),
      Rank(
        id: 2,
        name: 'Student Form',
        minBalance: 50,
        maxBalance: 100,
        dailyProfitPct: 2.0,
        copyTradesLimit: 2,
        color: '#2196F3',
      ),
      Rank(
        id: 3,
        name: 'Market Maven',
        minBalance: 100,
        maxBalance: 500,
        dailyProfitPct: 2.0,
        copyTradesLimit: 3,
        color: '#9C27B0',
      ),
      Rank(
        id: 4,
        name: 'Gunslinger',
        minBalance: 500,
        maxBalance: 1500,
        dailyProfitPct: 2.2,
        copyTradesLimit: 4,
        color: '#FF9800',
      ),
      Rank(
        id: 5,
        name: 'Whale',
        minBalance: 1500,
        maxBalance: 5000,
        dailyProfitPct: 2.5,
        copyTradesLimit: 5,
        color: '#FFC107',
      ),
      Rank(
        id: 6,
        name: 'Market Wizard',
        minBalance: 5000,
        maxBalance: openEndedMaxBalance,
        dailyProfitPct: 2.7,
        copyTradesLimit: 6,
        color: '#FFD700',
      ),
    ];
  }

  /// Django `Profile.get_rank`: ordered by min balance, first tier where
  /// `principal >= min` and (`max` is open-ended or `principal <= max`).
  static Rank? rankForPrincipal(double principal, List<Rank> ranks) {
    if (principal <= 0 || ranks.isEmpty) return null;
    final sorted = [...ranks]..sort((a, b) => a.minBalance.compareTo(b.minBalance));
    for (final r in sorted) {
      if (principal < r.minBalance) continue;
      final openEnded = r.maxBalance >= openEndedMaxBalance - 1;
      if (openEnded || principal <= r.maxBalance) {
        return r;
      }
    }
    return null;
  }

  static double roundMoney(double v) => (v * 100).round() / 100.0;

  /// Django `generate_daily_profit`: uses **locked** balance × rank daily %.
  static double dailyProfitLockedOnly(Profile profile, Rank? rank) {
    final r = rank ?? profile.rank;
    if (r == null || profile.lockedBalance <= 0) return 0;
    return roundMoney(profile.lockedBalance * (r.dailyProfitPct / 100.0));
  }

  /// Node `POST /copy-trades/simulate`: `(locked + withdrawable) * dailyProfitPct / 100`.
  static double dailyProfitOnPrincipalForCopySim(Profile profile, Rank? rank) {
    final r = rank ?? profile.rank;
    final pct = (r?.dailyProfitPct ?? 2.0) / 100.0;
    if (profile.totalBalance <= 0) return 0;
    return roundMoney(profile.totalBalance * pct);
  }

  static bool canClaimRankDailyProfitToday(Profile profile) {
    final last = profile.lastDailyProfitAt;
    if (last == null) return true;
    final now = DateTime.now();
    return last.year != now.year || last.month != now.month || last.day != now.day;
  }

  /// Progress toward the next rank (same idea as `rank_utils.get_rank_progress`).
  static (Rank? current, Rank? next, double progressPct) rankProgress(
    Profile profile,
    List<Rank> ranks,
  ) {
    final current = rankForPrincipal(profile.totalBalance, ranks);
    if (current == null) return (null, null, 0.0);
    final sorted = [...ranks]..sort((a, b) => a.minBalance.compareTo(b.minBalance));
    Rank? next;
    for (final r in sorted) {
      if (r.minBalance > current.minBalance) {
        next = r;
        break;
      }
    }
    if (next == null) return (current, null, 100.0);
    final bal = profile.totalBalance;
    final rangeStart = current.minBalance;
    final rangeEnd = next.minBalance;
    if (bal >= rangeEnd) return (current, next, 100.0);
    if (rangeEnd <= rangeStart) return (current, next, 100.0);
    final raw = ((bal - rangeStart) / (rangeEnd - rangeStart)) * 100.0;
    return (current, next, raw.clamp(0.0, 100.0));
  }

  /// Recompute [Profile.rank] / [Profile.rankId] from locked balance only.
  static Profile withResolvedRank(Profile profile, List<Rank> ranks) {
    final r = rankForPrincipal(profile.lockedBalance, ranks);
    if (r == null) {
      return profile.copyWith(rank: null);
    }
    return profile.copyWith(rankId: r.id, rank: r);
  }

  static List<Rank> ranksWithCurrentFlag(List<Rank> ranks, int? currentRankId) {
    return ranks
        .map((r) => r.copyWith(isCurrent: currentRankId != null && r.id == currentRankId))
        .toList();
  }
}
