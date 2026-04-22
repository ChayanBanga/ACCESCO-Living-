import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_drawer.dart';
import '../utils/app_colors.dart';

class CalcAIScreen extends StatefulWidget {
  const CalcAIScreen({super.key});

  @override
  State<CalcAIScreen> createState() => _CalcAIScreenState();
}

class _CalcAIScreenState extends State<CalcAIScreen> {
  final _incomeController = TextEditingController(text: '50000');
  final _rentController   = TextEditingController(text: '15000');

  String _selectedCity      = 'Mumbai';
  String _selectedLifestyle = 'Working Professional';
  int    _householdSize     = 1;

  double _needs   = 0;
  double _wants   = 0;
  double _savings = 0;

  final List<String> _cities = [
    'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai', 'Pune',
  ];
  final List<String> _lifestyles = [
    'Student', 'Working Professional', 'Family', 'Senior',
  ];

  @override
  void initState() {
    super.initState();
    _calculateBudget();
  }

  void _calculateBudget() {
    final income = double.tryParse(_incomeController.text) ?? 50000;
    final rent   = double.tryParse(_rentController.text)   ?? 15000;
    setState(() {
      _needs   = rent + (income * 0.30);
      _wants   = income * 0.30;
      _savings = income * 0.20;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    const double bannerH = 220.0;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── FULL-BLEED HERO BANNER ─────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: topPadding + bannerH,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [

                  // Actual banner image — no SafeArea, touches status bar
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/calciq_banner.jpg',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.8, 0.0),
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF880E4F), Color(0xFFC2185B), Color(0xFFE91E63)],
                          ),
                        ),
                        child: const Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('CalcIQ',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                                    color: Colors.white, letterSpacing: 2)),
                            SizedBox(height: 6),
                            Text("'WITHIN YOUR BUDGET'",
                                style: TextStyle(fontSize: 13, color: Colors.white70,
                                    fontStyle: FontStyle.italic)),
                          ]),
                        ),
                      ),
                    ),
                  ),

                  // Top scrim so icons are readable over any image
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.50),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Overlaid header row
                  Positioned(
                    top: topPadding + 2,
                    left: 4, right: 12, height: 56,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Builder(
                          builder: (ctx) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CalcIQ',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            Text('Smart budget planning',
                                style: TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.calculate, color: Colors.white, size: 26),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── SCROLLABLE CONTENT ─────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Summary Cards
                Row(children: [
                  Expanded(child: _SummaryCard(title: 'Needs', amount: _needs,
                      color: const Color(0xFFE57373), icon: Icons.home)),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(title: 'Wants', amount: _wants,
                      color: const Color(0xFFFFC107), icon: Icons.shopping_bag)),
                ]),
                const SizedBox(height: 12),
                _SummaryCard(title: 'Savings', amount: _savings,
                    color: const Color(0xFF0C831F), icon: Icons.savings, fullWidth: true),

                const SizedBox(height: 24),

                // Pie Chart
                Container(
                  height: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    sections: [
                      PieChartSectionData(
                        value: _needs,
                        title: '${((_needs / (_needs + _wants + _savings)) * 100).toStringAsFixed(0)}%',
                        color: const Color(0xFFE57373), radius: 60,
                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        value: _wants,
                        title: '${((_wants / (_needs + _wants + _savings)) * 100).toStringAsFixed(0)}%',
                        color: const Color(0xFFFFC107), radius: 60,
                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      PieChartSectionData(
                        value: _savings,
                        title: '${((_savings / (_needs + _wants + _savings)) * 100).toStringAsFixed(0)}%',
                        color: const Color(0xFF0C831F), radius: 60,
                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  )),
                ),

                const SizedBox(height: 24),

                const Text('Monthly Income', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _incomeController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calculateBudget(),
                  decoration: InputDecoration(
                    prefixText: '₹ ', filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 16),

                const Text('Rent/EMI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _rentController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calculateBudget(),
                  decoration: InputDecoration(
                    prefixText: '₹ ', filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 16),

                const Text('City', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCity, isExpanded: true,
                      items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCity = v!),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text('Lifestyle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLifestyle, isExpanded: true,
                      items: _lifestyles.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) => setState(() => _selectedLifestyle = v!),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text('Household Size', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  IconButton(
                    onPressed: () { if (_householdSize > 1) setState(() => _householdSize--); },
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF0C831F)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text('$_householdSize',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _householdSize++),
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0C831F)),
                  ),
                ]),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _calculateBudget,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('CALCULATE PLAN →',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SUMMARY CARD
// ════════════════════════════════════════════════════════════════════
class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final bool fullWidth;

  const _SummaryCard({
    required this.title, required this.amount,
    required this.color, required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
          ]),
          const SizedBox(height: 8),
          Text('₹${amount.toInt()}',
              style: TextStyle(fontSize: fullWidth ? 24 : 20,
                  fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}