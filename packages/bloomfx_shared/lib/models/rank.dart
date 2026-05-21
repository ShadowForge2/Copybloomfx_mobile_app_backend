class Rank {
  final int id;
  final String name;
  final double minBalance;
  final double maxBalance;
  final double dailyProfitPct;
  final int copyTradesLimit;
  final String color;
  final bool isCurrent;

  Rank({
    required this.id,
    required this.name,
    this.minBalance = 0,
    this.maxBalance = 0,
    this.dailyProfitPct = 0,
    this.copyTradesLimit = 1,
    this.color = '#6366f1',
    this.isCurrent = false,
  });

  factory Rank.fromJson(Map<String, dynamic> json) {
    return Rank(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      minBalance: (json['minBalance'] as num?)?.toDouble() ?? (json['min_balance'] as num?)?.toDouble() ?? 0,
      maxBalance: (json['maxBalance'] as num?)?.toDouble() ?? (json['max_balance'] as num?)?.toDouble() ?? 0,
      dailyProfitPct: (json['dailyProfitPct'] as num?)?.toDouble() ?? (json['daily_profit_pct'] as num?)?.toDouble() ?? 0,
      copyTradesLimit: json['copyTradesLimit'] as int? ?? json['copy_trades_limit'] as int? ?? 1,
      color: json['color']?.toString() ?? '#6366f1',
      isCurrent: json['isCurrent'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'minBalance': minBalance,
      'maxBalance': maxBalance,
      'dailyProfitPct': dailyProfitPct,
      'copyTradesLimit': copyTradesLimit,
      'color': color,
      'isCurrent': isCurrent,
    };
  }

  Rank copyWith({bool? isCurrent}) {
    return Rank(
      id: id,
      name: name,
      minBalance: minBalance,
      maxBalance: maxBalance,
      dailyProfitPct: dailyProfitPct,
      copyTradesLimit: copyTradesLimit,
      color: color,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}
