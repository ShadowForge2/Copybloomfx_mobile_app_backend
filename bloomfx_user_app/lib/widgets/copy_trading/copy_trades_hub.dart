import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/dashboard_provider.dart';
import '../../providers/theme_provider.dart';
import 'copy_trade_premium_card.dart';

/// Dashboard copy-trades region: presentation-only UX (tabs, empty states, place CTA).
class CopyTradesHub extends StatefulWidget {
  const CopyTradesHub({
    super.key,
    required this.dashboardData,
    required this.isSimulating,
    required this.onPlaceTrade,
    required this.colors,
  });

  final DashboardData? dashboardData;
  final bool isSimulating;
  final Future<void> Function() onPlaceTrade;
  final AppColors colors;

  @override
  State<CopyTradesHub> createState() => _CopyTradesHubState();
}

class _CopyTradesHubState extends State<CopyTradesHub>
    with SingleTickerProviderStateMixin {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final trades = widget.dashboardData?.copyTrades ?? [];
    final limit = widget.dashboardData?.copyTradesLimit ?? 1;
    final active = trades.where((t) => !t.isDone).toList();
    final history = trades.where((t) => t.isDone).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
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
                    Text(
                      'Copy Trades',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$limit trade(s) per day · WAT midnight reset',
                      style: TextStyle(
                        color: limit == 0
                            ? c.error.withValues(alpha: 0.9)
                            : c.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _PlaceTradeButton(
                busy: widget.isSimulating,
                colors: c,
                onPressed: widget.onPlaceTrade,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Trades follow server timing; on-screen motion and phases are for clarity only.',
            style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.25),
          ),
          if (widget.isSimulating) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: c.border.withValues(alpha: 0.4),
                color: c.accentBlue,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Consumer<DashboardProvider>(
            builder: (context, dash, _) => _SegmentTabs(
              colors: c,
              index: _segment,
              activeCount: active.length,
              historyCount: dash.unseenHistoryCount,
              onChanged: (i) {
                setState(() => _segment = i);
                if (i == 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      dash.markHistoryViewed();
                    } catch (_) {}
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _segment == 0
                ? _TradeListPanel(
                    key: const ValueKey('active'),
                    emptyTitle: 'No active copy trades',
                    emptySubtitle:
                        'When you place a trade, a live card appears here instantly with session progress.',
                    emptyIcon: Icons.show_chart_rounded,
                    trades: active,
                    colors: c,
                  )
                : _TradeListPanel(
                    key: const ValueKey('history'),
                    emptyTitle: 'No completed trades yet',
                    emptySubtitle:
                        'Closed sessions are listed here with final P/L preserved from the server.',
                    emptyIcon: Icons.history_rounded,
                    trades: history,
                    colors: c,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.colors,
    required this.index,
    required this.activeCount,
    required this.historyCount,
    required this.onChanged,
  });

  final AppColors colors;
  final int index;
  final int activeCount;
  final int historyCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SegmentChip(
            label: 'Active',
            count: activeCount,
            selected: index == 0,
            colors: colors,
            onTap: () => onChanged(0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SegmentChip(
            label: 'History',
            count: historyCount,
            selected: index == 1,
            colors: colors,
            onTap: () => onChanged(1),
          ),
        ),
      ],
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? colors.textPrimary : colors.textSecondary;
    final bg = selected
        ? colors.accentBlue.withValues(alpha: 0.18)
        : colors.surfaceBg;
    final border = selected
        ? colors.accentBlue.withValues(alpha: 0.55)
        : colors.border;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: colors.accentBlue.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentBlue.withValues(
                      alpha: selected ? 0.35 : 0.2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TradeListPanel extends StatelessWidget {
  const _TradeListPanel({
    super.key,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.trades,
    required this.colors,
  });

  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final List<CopyTrade> trades;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    if (trades.isEmpty) {
      return _EmptyTrades(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        colors: c,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < trades.length && i < 20; i++)
          CopyTradePremiumCard(
            key: ValueKey(trades[i].id),
            trade: trades[i],
            colors: c,
          ),
      ],
    );
  }
}

class _EmptyTrades extends StatelessWidget {
  const _EmptyTrades({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: c.iconColor.withValues(alpha: 0.85)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceTradeButton extends StatefulWidget {
  const _PlaceTradeButton({
    required this.busy,
    required this.colors,
    required this.onPressed,
  });

  final bool busy;
  final AppColors colors;
  final Future<void> Function() onPressed;

  @override
  State<_PlaceTradeButton> createState() => _PlaceTradeButtonState();
}

class _PlaceTradeButtonState extends State<_PlaceTradeButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Material(
          elevation: widget.busy ? 0 : 2,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(10),
          color: c.accentBlue,
          child: InkWell(
            onTap: widget.busy ? null : () => widget.onPressed(),
            borderRadius: BorderRadius.circular(10),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: widget.busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Place Copy Trade',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
