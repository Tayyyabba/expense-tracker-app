import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpenseTrackerApp());
}

const Color ink = Color(0xFF29205B);
const Color purple = Color(0xFF6C55D9);
const Color pale = Color(0xFFF5F2FF);
const Color green = Color(0xFF238765);
const Color red = Color(0xFFD64C64);

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: purple),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F7FC),
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E4F2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E4F2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: purple, width: 1.5),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final String type; // Income or Expense
  final String category;
  final DateTime date;
  final String note;

  const TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type,
        'category': category,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        type: json['type'] as String,
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
        note: (json['note'] as String?) ?? '',
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _storageKey = 'expense_tracker_transactions_v1';
  final List<TransactionItem> _items = [];
  bool _loading = true;
  int _tab = 0;
  String _typeFilter = 'All';
  String _categoryFilter = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  final List<String> _categories = const [
    'Food', 'Transport', 'Shopping', 'Bills', 'Health',
    'Education', 'Salary', 'Business', 'Gift', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(decoded.map((e) =>
              TransactionItem.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {
      // If stored data is corrupted, the app still opens safely.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  double get _totalIncome => _items
      .where((e) => e.type == 'Income')
      .fold(0, (sum, e) => sum + e.amount);

  double get _totalExpense => _items
      .where((e) => e.type == 'Expense')
      .fold(0, (sum, e) => sum + e.amount);

  List<TransactionItem> get _monthItems => _items.where((e) =>
      e.date.year == _month.year && e.date.month == _month.month).toList();

  double get _monthIncome => _monthItems
      .where((e) => e.type == 'Income')
      .fold(0, (sum, e) => sum + e.amount);

  double get _monthExpense => _monthItems
      .where((e) => e.type == 'Expense')
      .fold(0, (sum, e) => sum + e.amount);

  List<TransactionItem> get _filteredItems {
    final result = _items.where((e) {
      if (_typeFilter != 'All' && e.type != _typeFilter) return false;
      if (_categoryFilter != 'All' && e.category != _categoryFilter) return false;
      if (_fromDate != null &&
          DateUtils.dateOnly(e.date).isBefore(DateUtils.dateOnly(_fromDate!))) {
        return false;
      }
      if (_toDate != null &&
          DateUtils.dateOnly(e.date).isAfter(DateUtils.dateOnly(_toDate!))) {
        return false;
      }
      return true;
    }).toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.of(context).push<TransactionItem>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(categories: _categories),
      ),
    );
    if (result == null) return;
    setState(() => _items.add(result));
    await _saveItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved successfully')),
      );
    }
  }

  Future<void> _deleteTransaction(TransactionItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Remove "${item.title}" from your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _items.removeWhere((e) => e.id == item.id));
      await _saveItems();
    }
  }

  Future<void> _chooseDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _exportCsv() async {
    final rows = <List<String>>[
      ['Title', 'Type', 'Category', 'Amount', 'Date', 'Note'],
      ..._filteredItems.map((e) => [
            e.title, e.type, e.category, e.amount.toStringAsFixed(2),
            DateFormat('yyyy-MM-dd').format(e.date), e.note
          ]),
    ];
    String escape(String value) {
      final safe = value.replaceAll('"', '""');
      return '"$safe"';
    }
    final csv = rows.map((r) => r.map(escape).join(',')).join('\n');
    await Share.shareXFiles(
      [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: 'transactions.csv')],
      text: 'Expense Tracker transactions CSV',
      subject: 'Transactions export',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Expense Tracker',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            Text(
              _tab == 0 ? 'Your money, made clearer' : 'Your transaction history',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: _items.isEmpty ? null : _exportCsv,
            icon: const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: _tab == 0 ? _dashboard() : _history(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        backgroundColor: purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
        ],
      ),
    );
  }

  Widget _dashboard() {
    final balance = _totalIncome - _totalExpense;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C55D9), Color(0xFF44318F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: purple.withOpacity(.2), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
                const SizedBox(width: 8),
                const Text('TOTAL BALANCE', style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Text(_money(balance),
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _balanceMetric('Income', _totalIncome, Icons.south_west_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _balanceMetric('Expenses', _totalExpense, Icons.north_east_rounded)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(child: Text('This month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink))),
          IconButton(
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          Text(DateFormat('MMM yyyy').format(_month), style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _summaryCard('Income', _monthIncome, green, Icons.trending_up_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _summaryCard('Spent', _monthExpense, red, Icons.trending_down_rounded)),
        ]),
        const SizedBox(height: 22),
        _monthlyChart(),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(child: Text('Recent transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink))),
          TextButton(onPressed: () => setState(() => _tab = 1), child: const Text('See all')),
        ]),
        if (_items.isEmpty)
          _emptyState('Nothing here yet', 'Add your first transaction to see it here.')
        else
          ...(_items.toList()..sort((a, b) => b.date.compareTo(a.date)))
              .take(4)
              .map((e) => _transactionTile(e)),
      ],
    );
  }

  Widget _balanceMetric(String label, double amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 3),
          FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
            child: Text(_money(amount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
        ])),
      ]),
    );
  }

  Widget _summaryCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECE8F5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 17, backgroundColor: color.withOpacity(.1), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
          child: Text(_money(amount), style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _monthlyChart() {
    final values = List<double>.generate(6, (i) {
      final month = DateTime(_month.year, _month.month - (5 - i));
      return _items.where((e) => e.type == 'Expense' && e.date.year == month.year && e.date.month == month.month)
          .fold<double>(0, (sum, e) => sum + e.amount);
    });
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Spending overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 4),
        Text('Expenses over the last 6 months', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(
          height: 145,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(6, (i) {
              final month = DateTime(_month.year, _month.month - (5 - i));
              final fraction = maxValue == 0 ? 0.0 : values[i] / maxValue;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (values[i] > 0)
                      FittedBox(child: Text(_compact(values[i]), style: const TextStyle(fontSize: 9, color: ink, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      height: 82 * (fraction == 0 ? .035 : fraction),
                      decoration: BoxDecoration(
                        color: i == 5 ? purple : const Color(0xFFCFC5FA),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(DateFormat('MMM').format(month), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _history() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
      children: [
        const Text('Transaction history', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _typeFilter,
            decoration: const InputDecoration(labelText: 'Type', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: ['All', 'Income', 'Expense'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _typeFilter = v ?? 'All'),
          )),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(
            value: _categoryFilter,
            decoration: const InputDecoration(labelText: 'Category', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: ['All', ..._categories].map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _categoryFilter = v ?? 'All'),
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _chooseDate(true),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(_fromDate == null ? 'From date' : DateFormat('dd MMM yy').format(_fromDate!)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _chooseDate(false),
            icon: const Icon(Icons.event, size: 18),
            label: Text(_toDate == null ? 'To date' : DateFormat('dd MMM yy').format(_toDate!)),
          )),
          IconButton(
            tooltip: 'Clear filters',
            onPressed: () => setState(() { _typeFilter = 'All'; _categoryFilter = 'All'; _fromDate = null; _toDate = null; }),
            icon: const Icon(Icons.filter_alt_off),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${_filteredItems.length} transaction(s)', style: TextStyle(color: Colors.grey.shade600))),
          TextButton.icon(onPressed: _items.isEmpty ? null : _exportCsv, icon: const Icon(Icons.ios_share, size: 17), label: const Text('Export CSV')),
        ]),
        if (_filteredItems.isEmpty)
          _emptyState('No transactions found', 'Try changing your filters or add a transaction.')
        else
          ..._filteredItems.map((e) => _transactionTile(e, onDelete: () => _deleteTransaction(e))),
      ],
    );
  }

  Widget _transactionTile(TransactionItem item, {VoidCallback? onDelete}) {
    final isIncome = item.type == 'Income';
    final color = isIncome ? green : red;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F5))),
      child: Row(children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: color.withOpacity(.1),
          child: Icon(_categoryIcon(item.category), color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 4),
          Text('${item.category} • ${DateFormat('dd MMM yyyy').format(item.date)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(item.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ])),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isIncome ? '+' : '−'}${_money(item.amount)}',
              style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
          if (onDelete != null)
            SizedBox(height: 26, child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade500),
            )),
        ]),
      ]),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: pale, shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_outlined, color: purple, size: 30),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 5),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ]),
    );
  }

  String _money(double value) => 'Rs ${NumberFormat('#,##0.00').format(value)}';
  String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Food': return Icons.restaurant_rounded;
      case 'Transport': return Icons.directions_bus_rounded;
      case 'Shopping': return Icons.shopping_bag_rounded;
      case 'Bills': return Icons.receipt_long_rounded;
      case 'Health': return Icons.favorite_rounded;
      case 'Education': return Icons.school_rounded;
      case 'Salary': return Icons.work_rounded;
      case 'Business': return Icons.store_rounded;
      case 'Gift': return Icons.card_giftcard_rounded;
      default: return Icons.category_rounded;
    }
  }
}

class AddTransactionScreen extends StatefulWidget {
  final List<String> categories;
  const AddTransactionScreen({super.key, required this.categories});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _type = 'Expense';
  String _category = 'Food';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final item = TransactionItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      amount: double.parse(_amount.text.trim()),
      type: _type,
      category: _category,
      date: _date,
      note: _note.text.trim(),
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(Icons.edit_note_rounded, color: purple, size: 30),
                  SizedBox(width: 12),
                  Expanded(child: Text('Record your money movement', style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 16))),
                ]),
              ),
              const SizedBox(height: 24),
              const Text('Transaction type', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Expense', label: Text('Expense'), icon: Icon(Icons.north_east_rounded)),
                  ButtonSegment(value: 'Income', label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _category = _type == 'Income' ? 'Salary' : 'Food';
                }),
              ),
              const SizedBox(height: 20),
              const Text('Title', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'e.g. Grocery shopping', prefixIcon: Icon(Icons.short_text)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 18),
              const Text('Amount (PKR)', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: '0.00', prefixIcon: Icon(Icons.currency_exchange)),
                validator: (v) {
                  final value = double.tryParse((v ?? '').trim());
                  if (value == null || !value.isFinite || value <= 0) return 'Enter an amount greater than zero';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 18),
              const Text('Date', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(DateFormat('EEEE, dd MMMM yyyy').format(_date)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), alignment: Alignment.centerLeft),
              ),
              const SizedBox(height: 18),
              const Text('Note (optional)', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _note,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Add a short note...'),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Saving...' : 'Save transaction'),
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
