import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:bloomfx_shared/models/user.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedTimeRange = '1d';
  String _selectedAccount = 'E8 Account 2110113586';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.user == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final user = authProvider.user!;
          return SafeArea(
            child: Column(
              children: [
                _buildHeader(context, user),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBalanceSection(),
                        const SizedBox(height: 24),
                        _buildAccountLossAnalysis(),
                        const SizedBox(height: 24),
                        _buildPerformanceMetrics(),
                        const SizedBox(height: 24),
                        _buildGoalOverview(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Color(0xFF7D8590)),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF7D8590)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Account Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: DropdownButton<String>(
              value: _selectedAccount,
              dropdownColor: const Color(0xFF21262D),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'E8 Account 2110113586', child: Text('E8 Account 2110113586')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAccount = value!;
                });
              },
            ),
          ),
          
          const SizedBox(width: 16),
          
          // User Profile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF7D8590), size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      user.email ?? 'No email',
                      style: const TextStyle(color: Color(0xFF7D8590), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF7D8590)),
                  color: const Color(0xFF21262D),
                  onSelected: (value) {
                    if (value == 'logout') {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final router = GoRouter.of(context);
                      authProvider.logout();
                      router.go('/login');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'logout',
                      child: Text('Logout', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Balance',
            style: TextStyle(
              color: Color(0xFF7D8590),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '\$38,154 USD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1000,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0xFF30363D),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 1000,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${(value ~/ 1000)}k',
                          style: const TextStyle(color: Color(0xFF7D8590), fontSize: 10),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const dates = ['Apr 6', 'Apr 7', 'Apr 8', 'Apr 9', 'Apr 10', 'Apr 11', 'Apr 12'];
                        if (value.toInt() >= 0 && value.toInt() < dates.length) {
                          return Text(
                            dates[value.toInt()],
                            style: const TextStyle(color: Color(0xFF7D8590), fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 37000),
                      FlSpot(1, 37500),
                      FlSpot(2, 38154),
                      FlSpot(3, 37800),
                      FlSpot(4, 38200),
                      FlSpot(5, 37900),
                      FlSpot(6, 38154),
                    ],
                    isCurved: true,
                    color: const Color(0xFF58A6FF),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF58A6FF).withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF21262D),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        return LineTooltipItem(
                          '\$${spot.y.toStringAsFixed(0)} USD',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Time Range Selector
          Row(
            children: ['1s', '15m', '1h', '4h', '1d', '1w'].map((time) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeRange = time;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedTimeRange == time
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Text(
                      time,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedTimeRange == time ? Colors.white : const Color(0xFF7D8590),
                        fontSize: 12,
                        fontWeight: _selectedTimeRange == time ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountLossAnalysis() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Account Loss Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Max Recorded', true),
                    _buildTabButton('Current', false),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildLossLevelCard(
            'Initial Deposit Limit Level',
            'Initial Deposit',
            '\$25,000.0',
            'Loss Level',
            '\$230,000.00',
            0.89,
          ),
          
          const SizedBox(height: 16),
          
          _buildLossLevelCard(
            'Daily Loss Limit Level',
            'Entry Equity',
            '\$25,000.0',
            'Loss Level',
            '\$237,000.00',
            0.95,
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF7D8590), size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Next Daily Loss Reset in',
                  style: TextStyle(color: Color(0xFF7D8590), fontSize: 12),
                ),
                const Spacer(),
                const Text(
                  '12:36:36',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF58A6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFF7D8590),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLossLevelCard(
    String title,
    String label1,
    String value1,
    String label2,
    String value2,
    double progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label1, style: const TextStyle(color: Color(0xFF7D8590), fontSize: 12)),
                    Text(value1, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label2, style: const TextStyle(color: Color(0xFF7D8590), fontSize: 12)),
                    Text(value2, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: progress > 0.9 ? Colors.red : progress > 0.7 ? Colors.orange : const Color(0xFF58A6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Average Win', '\$987.47', Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('Average Loss', '-\$781.70', Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Win Ratio', '66%', const Color(0xFF58A6FF))),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('Risk Reward', '66%', const Color(0xFF58A6FF))),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF7D8590), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Goal Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildGoalCard(
            'Minimum Trading Days',
            'Minimum Result: 1 Days',
            'Current Result: 1 Days',
            true,
          ),
          
          const SizedBox(height: 12),
          
          _buildGoalCard(
            'Profit Target',
            'Minimum Result: US\$400.00',
            'Current Result: US\$411.18',
            true,
          ),
          
          const SizedBox(height: 12),
          
          _buildGoalCard(
            'Initial Balance Loss',
            'Minimum Result: US\$400.00',
            'Current Result: US\$0.00',
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(String title, String minResult, String currentResult, bool passes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: passes ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  passes ? 'Passes' : 'Fails',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            minResult,
            style: const TextStyle(color: Color(0xFF7D8590), fontSize: 12),
          ),
          Text(
            currentResult,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
