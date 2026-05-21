import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';
import '../../providers/theme_provider.dart';

/// Cosmetic presentation phases only — derived from timestamps and existing [CopyTrade] status.
String copyTradePresentationPhase(CopyTrade trade) {
  if (trade.isDone) return 'Trade closed';
  final elapsed = DateTime.now().difference(trade.createdAt);
  if (elapsed.inSeconds < 2) return 'Searching for a safe setup...';
  if (elapsed.inSeconds < 30) return 'Applying setup...';
  return 'Trade opened';
}

class CopyTradeSparkline extends StatefulWidget {
  const CopyTradeSparkline({
    super.key,
    required this.bullish,
    required this.colors,
  });

  final bool bullish;
  final AppColors colors;

  @override
  State<CopyTradeSparkline> createState() => _CopyTradeSparklineState();
}

class _CopyTradeSparklineState extends State<CopyTradeSparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _SparkPainter(
              phase: _ctrl.value * math.pi * 2,
              bullish: widget.bullish,
              accent: widget.colors.accentBlue,
              line: widget.colors.border,
            ),
            size: const Size(double.infinity, 44),
          );
        },
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.phase,
    required this.bullish,
    required this.accent,
    required this.line,
  });

  final double phase;
  final bool bullish;
  final Color accent;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final base = bullish ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
    final g = Rect.fromLTWH(0, 0, size.width, size.height);
    final bg = Paint()
      ..shader = LinearGradient(
        colors: [
          base.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(g);
    canvas.drawRect(g, bg);

    final path = Path();
    const segments = 28;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = t * size.width;
      final wobble = math.sin(t * 5 + phase) * 0.08 + math.sin(t * 11 - phase * 0.7) * 0.04;
      final y = size.height * (0.55 + wobble * (bullish ? -1 : 1));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = bullish ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);
    canvas.drawPath(path, stroke);

    final shimmer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, shimmer);

    final grid = Paint()
      ..color = line.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.bullish != bullish ||
        oldDelegate.accent != accent;
  }
}

class CopyTradePremiumCard extends StatefulWidget {
  const CopyTradePremiumCard({
    super.key,
    required this.trade,
    required this.colors,
  });

  final CopyTrade trade;
  final AppColors colors;

  @override
  State<CopyTradePremiumCard> createState() => _CopyTradePremiumCardState();
}

class _CopyTradePremiumCardState extends State<CopyTradePremiumCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _entrance;
  late final AnimationController _completeFlash;
  AnimationController? _profitJitter;
  Timer? _fluctuationTimer;
  final math.Random _rand = math.Random();
  bool _wasDone = false;
  double _profitAnimFrom = 0;
  double _profitAnimTo = 0;
  double _visibleProfit = 0;

  @override
  void initState() {
    super.initState();
    _wasDone = widget.trade.isDone;
    _profitAnimTo = widget.trade.profit ?? 0;
    _profitAnimFrom = _profitAnimTo;
    _visibleProfit = widget.trade.isDone ? _profitAnimTo : 0;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _completeFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entrance.forward(from: 0);
    _maybeStartProfitJitter();
    _startFluctuation();
  }

  void _startFluctuation() {
    if (widget.trade.isDone) return;
    _scheduleFluctuationTick();
  }

  void _scheduleFluctuationTick() {
    if (!mounted || widget.trade.isDone) {
      _profitAnimFrom = _visibleProfit;
      _visibleProfit = _profitAnimTo;
      if (mounted) setState(() {});
      return;
    }
    final pause = Duration(milliseconds: 1000 + _rand.nextInt(3001));
    _fluctuationTimer = Timer(pause, () {
      if (!mounted || widget.trade.isDone) {
        _profitAnimFrom = _visibleProfit;
        _visibleProfit = _profitAnimTo;
        if (mounted) setState(() {});
        return;
      }
      final progress = _progress(widget.trade);
      final range = (1.0 - progress * 0.85) * 0.6;
      final drift = (_rand.nextDouble() - 0.3) * range * 2;
      final target = _profitAnimTo;
      final next = (target + drift).clamp(target - range, target + range + 0.3);
      _profitAnimFrom = _visibleProfit;
      _visibleProfit = double.parse(next.toStringAsFixed(2));
      setState(() {});
      _scheduleFluctuationTick();
    });
  }

  void _maybeStartProfitJitter() {
    if (!widget.trade.isDone && (widget.trade.profit ?? 0) != 0) {
      _profitJitter ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat(reverse: true);
    } else {
      _profitJitter?.dispose();
      _profitJitter = null;
    }
  }

  @override
  void didUpdateWidget(covariant CopyTradePremiumCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextProfit = widget.trade.profit ?? 0;
    if (nextProfit != _profitAnimTo) {
      _profitAnimFrom = _profitAnimTo;
      _profitAnimTo = nextProfit;
    }
    if (!_wasDone && widget.trade.isDone) {
      _fluctuationTimer?.cancel();
      _fluctuationTimer = null;
      _profitAnimFrom = _visibleProfit;
      _visibleProfit = _profitAnimTo;
      _completeFlash.forward(from: 0);
    }
    _wasDone = widget.trade.isDone;
    if (oldWidget.trade.id != widget.trade.id) {
      _fluctuationTimer?.cancel();
      _fluctuationTimer = null;
      _entrance.forward(from: 0);
      _visibleProfit = widget.trade.isDone ? _profitAnimTo : 0;
      _startFluctuation();
    }
    _maybeStartProfitJitter();
  }

  @override
  void dispose() {
    _fluctuationTimer?.cancel();
    _pulse.dispose();
    _entrance.dispose();
    _completeFlash.dispose();
    _profitJitter?.dispose();
    super.dispose();
  }

  double _progress(CopyTrade t) {
    final close = t.closeAt;
    if (close == null) return 0;
    final start = t.createdAt;
    final total = close.difference(start).inMilliseconds;
    if (total <= 0) return t.isDone ? 1 : 0;
    final gone = DateTime.now().difference(start).inMilliseconds;
    return (gone / total).clamp(0.0, 1.0);
  }

  double? _roiPct(CopyTrade t) {
    final p = t.profit;
    if (p == null) return null;
    if (t.entryPrice > 0) {
      return t.priceChangePct;
    }
    final lots = t.amount <= 0 ? 0.01 : t.amount;
    return (p / (lots * 100)) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final c = widget.colors;
    final isDone = t.isDone;
    final profit = t.profit ?? 0;
    final profitPositive = profit >= 0;
    final phase = copyTradePresentationPhase(t);
    final bull = t.action == 'buy';
    final timeFmt = DateFormat('MMM d, HH:mm');
    final roi = _roiPct(t);

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _pulse,
              _completeFlash,
              if (_profitJitter != null) _profitJitter!,
            ]),
            builder: (context, _) {
              // Use a simplified, professional layout for completed trades
              if (isDone) {
                final finalColor = profitPositive ? c.success : c.error;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: c.surfaceBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.pair,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Closed ${timeFmt.format((t.closeAt ?? t.createdAt).toLocal())}',
                                style: TextStyle(color: c.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatPl(profit),
                              style: TextStyle(
                                color: finalColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _StatusPill(trade: t, colors: c, pulse: _pulse.value),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              final borderGlow = isDone
                  ? (profitPositive ? c.success : c.error).withValues(
                      alpha: 0.35 + 0.25 * _completeFlash.value,
                    )
                  : c.accentBlue.withValues(alpha: 0.25 + 0.2 * _pulse.value);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderGlow, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.surfaceBg,
                      c.cardBg.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    children: [
                      if (_completeFlash.isAnimating)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  (profitPositive ? c.success : c.error)
                                      .withValues(alpha: 0.12 * (1 - _completeFlash.value)),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            t.pair,
                                            style: TextStyle(
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          if (!isDone) ...[
                                            const SizedBox(width: 8),
                                            _LiveDot(pulse: _pulse.value, colors: c),
                                            Text(
                                              ' LIVE',
                                              style: TextStyle(
                                                color: c.accentBlue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        phase,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _DirectionChip(bull: bull, colors: c),
                              ],
                            ),
                            const SizedBox(height: 10),
                            CopyTradeSparkline(
                              bullish: bull,
                              colors: c,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricTile(
                                    label: 'Volume (lots)',
                                    value: t.amount.toStringAsFixed(3),
                                    colors: c,
                                  ),
                                ),
                                Expanded(
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey('pl-${t.id}-$_visibleProfit'),
                                    tween: Tween(begin: _profitAnimFrom, end: _visibleProfit),
                                    duration: const Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, animatedProfit, _) {
                                      return _MetricTile(
                                        label: isDone ? 'Final P/L' : 'Open P/L',
                                        value: _formatPl(animatedProfit),
                                        colors: c,
                                        emphasize: true,
                                        positive: animatedProfit >= 0,
                                        jitter: _profitJitter?.value,
                                      );
                                    },
                                  ),
                                ),
                                if (roi != null)
                                  Expanded(
                                    child: _MetricTile(
                                      label: t.entryPrice > 0 ? 'Price Δ %' : 'ROI %',
                                      value: '${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(2)}%',
                                      colors: c,
                                      positive: roi >= 0,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 14, color: c.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Opened ${timeFmt.format(t.createdAt.toLocal())}',
                                    style: TextStyle(color: c.textMuted, fontSize: 11),
                                  ),
                                ),
                                _StatusPill(trade: t, colors: c, pulse: _pulse.value),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static String _formatPl(double v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign\$${v.abs().toStringAsFixed(2)}';
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.pulse, required this.colors});

  final double pulse;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.success.withValues(alpha: 0.35 + 0.55 * pulse),
        boxShadow: [
          BoxShadow(
            color: colors.success.withValues(alpha: 0.45),
            blurRadius: 4 + 4 * pulse,
          ),
        ],
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({required this.bull, required this.colors});

  final bool bull;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final bg = bull ? colors.success : colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bg.withValues(alpha: 0.55)),
      ),
      child: Text(
        bull ? 'BUY' : 'SELL',
        style: TextStyle(
          color: bg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.colors,
    this.emphasize = false,
    this.positive,
    this.jitter,
  });

  final String label;
  final String value;
  final AppColors colors;
  final bool emphasize;
  final bool? positive;
  final double? jitter;

  @override
  Widget build(BuildContext context) {
    Color valueColor = colors.textPrimary;
    if (positive != null) {
      valueColor = positive! ? colors.success : colors.error;
    }
    Widget text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: valueColor,
        fontSize: emphasize ? 15 : 12,
        fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (jitter != null && emphasize) {
      text = Transform.translate(
        offset: Offset(0, math.sin(jitter! * math.pi * 2) * 0.45),
        child: text,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 2),
          text,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.trade,
    required this.colors,
    required this.pulse,
  });

  final CopyTrade trade;
  final AppColors colors;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final isDone = trade.isDone;
    String label;
    Color fg;
    if (trade.isPending) {
      label = 'PENDING';
      fg = colors.warning;
    } else if (trade.isActive) {
      label = 'ACTIVE';
      fg = colors.accentBlue;
    } else if (trade.status == 'completed') {
      label = 'CLOSED +';
      fg = colors.success;
    } else if (trade.status == 'lost') {
      label = 'CLOSED −';
      fg = colors.error;
    } else {
      label = trade.status.toUpperCase();
      fg = colors.textSecondary;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: isDone ? 0.14 : 0.10 + 0.06 * pulse),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DurationBar extends StatelessWidget {
  const _DurationBar({
    required this.progress,
    required this.colors,
    required this.remaining,
    required this.isDone,
  });

  final double progress;
  final AppColors colors;
  final Duration? remaining;
  final bool isDone;

  static String _formatMmSs(Duration d) {
    if (d.isNegative) return '0:00';
    final totalSec = d.inSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remLabel = isDone
        ? 'Session complete'
        : (remaining != null ? '${_formatMmSs(remaining!)} left' : 'Duration —');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(color: colors.textMuted, fontSize: 10),
            ),
            Text(
              remLabel,
              style: TextStyle(color: colors.textSecondary, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: colors.border.withValues(alpha: 0.35),
                color: colors.accentBlue,
              );
            },
          ),
        ),
      ],
    );
  }
}
