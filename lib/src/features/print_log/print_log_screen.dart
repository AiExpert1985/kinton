import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/values/gaps.dart';
import 'package:tablets/src/common/widgets/show_transaction_dialog.dart';
import 'package:tablets/src/features/print_log/print_log_service.dart';
import 'package:tablets/src/features/transactions/model/transaction.dart';
import 'package:tablets/src/routers/go_router_provider.dart';
import 'package:tablets/src/common/widgets/main_drawer.dart';

/// Provider that holds the loaded print log entries
final printLogEntriesProvider =
    StateProvider<List<PrintLogEntry>>((ref) => []);

/// Provider that holds the filtered entries for display
final filteredPrintLogEntriesProvider =
    StateProvider<List<PrintLogEntry>>((ref) => []);

class PrintLogScreen extends ConsumerStatefulWidget {
  const PrintLogScreen({super.key});

  @override
  ConsumerState<PrintLogScreen> createState() => _PrintLogScreenState();
}

class _PrintLogScreenState extends ConsumerState<PrintLogScreen> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _selectedType;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    // Load entries after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntries();
    });
  }

  void _loadEntries() {
    final service = ref.read(printLogServiceProvider);
    final entries = service.loadAllEntries();
    // Sort newest first
    entries.sort((a, b) => b.printTime.compareTo(a.printTime));
    ref.read(printLogEntriesProvider.notifier).state = entries;
    ref.read(filteredPrintLogEntriesProvider.notifier).state = entries;
  }

  void _applyFilters() {
    final allEntries = ref.read(printLogEntriesProvider);
    var filtered = allEntries.toList();

    // Filter by transaction number
    final numberText = _numberController.text.trim();
    if (numberText.isNotEmpty) {
      final number = int.tryParse(numberText);
      if (number != null) {
        filtered = filtered
            .where((e) => e.transaction['number'] == number)
            .toList();
      }
    }

    // Filter by customer name
    final nameText = _nameController.text.trim();
    if (nameText.isNotEmpty) {
      filtered = filtered
          .where((e) =>
              (e.transaction['name'] ?? '').toString().contains(nameText))
          .toList();
    }

    // Filter by transaction type
    if (_selectedType != null && _selectedType!.isNotEmpty) {
      filtered = filtered
          .where((e) => e.transaction['transactionType'] == _selectedType)
          .toList();
    }

    // Filter by date
    if (_selectedDate != null) {
      filtered = filtered.where((e) {
        final entryDate = _parseTransactionDate(e.transaction['date']);
        if (entryDate == null) return false;
        return entryDate.year == _selectedDate!.year &&
            entryDate.month == _selectedDate!.month &&
            entryDate.day == _selectedDate!.day;
      }).toList();
    }

    ref.read(filteredPrintLogEntriesProvider.notifier).state = filtered;
  }

  DateTime? _parseTransactionDate(dynamic date) {
    if (date is DateTime) return date;
    if (date is String) return DateTime.tryParse(date);
    return null;
  }

  void _clearFilters() {
    _numberController.clear();
    _nameController.clear();
    setState(() {
      _selectedType = null;
      _selectedDate = null;
    });
    ref.read(filteredPrintLogEntriesProvider.notifier).state =
        ref.read(printLogEntriesProvider);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = ref.watch(filteredPrintLogEntriesProvider);
    final allEntries = ref.watch(printLogEntriesProvider);
    final hasFilters = _numberController.text.isNotEmpty ||
        _nameController.text.isNotEmpty ||
        _selectedType != null ||
        _selectedDate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الطباعة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(AppRoute.home.name),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filters row
            _buildFilters(context, hasFilters),
            VerticalGap.l,
            // Table header
            _buildTableHeader(),
            const Divider(thickness: 2),
            // Table data
            Expanded(
              child: allEntries.isEmpty
                  ? const Center(
                      child: Text('لا توجد سجلات طباعة',
                          style: TextStyle(fontSize: 18)))
                  : filteredEntries.isEmpty
                      ? const Center(
                          child: Text('لا توجد نتائج مطابقة',
                              style: TextStyle(fontSize: 16)))
                      : ListView.builder(
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = filteredEntries[index];
                            return Column(
                              children: [
                                InkWell(
                                  onTap: () => _showTransaction(context, entry),
                                  child: _buildTableRow(
                                      context, entry, index + 1),
                                ),
                                const Divider(thickness: 0.5),
                              ],
                            );
                          },
                        ),
            ),
            VerticalGap.l,
            // Missing transactions detection button (moved from SettingsDialog)
            const MissingTransactionsDetectionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, bool hasFilters) {
    return Row(
      children: [
        hasFilters
            ? IconButton(
                onPressed: _clearFilters,
                icon: const Icon(Icons.cancel_outlined, color: Colors.red))
            : const SizedBox(width: 40),
        HorizontalGap.l,
        // Transaction type filter
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedType,
            hint: const Text('نوع التعامل'),
            isExpanded: true,
            items: [
              'customerInvoice',
              'customerReceipt',
              'customerReturn',
              'vendorInvoice',
              'vendorReceipt',
              'vendorReturn',
              'expenditures',
              'gifts',
              'damagedItems',
            ]
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(translateDbTextToScreenText(context, type)),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => _selectedType = value);
              _applyFilters();
            },
          ),
        ),
        HorizontalGap.l,
        // Number filter
        Expanded(
          child: TextField(
            controller: _numberController,
            decoration: const InputDecoration(
              hintText: 'رقم التعامل',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            textAlign: TextAlign.center,
            onSubmitted: (_) => _applyFilters(),
          ),
        ),
        HorizontalGap.l,
        // Customer name filter
        Expanded(
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'اسم الزبون',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            textAlign: TextAlign.center,
            onSubmitted: (_) => _applyFilters(),
          ),
        ),
        HorizontalGap.l,
        // Date filter
        Expanded(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
                _applyFilters();
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                _selectedDate != null
                    ? DateFormat('dd-MM-yyyy').format(_selectedDate!)
                    : 'التاريخ',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      color: Colors.grey[200],
      child: const Row(
        children: [
          SizedBox(
              width: 40,
              child: Text('#',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('نوع التعامل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('الرقم',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('اسم الزبون',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('تاريخ التعامل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('تاريخ الطباعة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('نوع الطباعة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTableRow(
      BuildContext context, PrintLogEntry entry, int rowNumber) {
    final dateFormat = DateFormat('dd-MM-yyyy');
    final dateTimeFormat = DateFormat('dd-MM-yyyy HH:mm');

    // Parse transaction date
    String transactionDate = '';
    final dateValue = entry.transaction['date'];
    if (dateValue is String) {
      final parsed = DateTime.tryParse(dateValue);
      if (parsed != null) {
        transactionDate = dateFormat.format(parsed);
      } else {
        transactionDate = dateValue;
      }
    } else if (dateValue is DateTime) {
      transactionDate = dateFormat.format(dateValue);
    }

    final printTypeText =
        entry.printType == 'local' ? 'طباعة محلية' : 'ارسال للمخزن';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(rowNumber.toString(), textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(
              translateDbTextToScreenText(
                  context, entry.transaction['transactionType'] ?? ''),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              (entry.transaction['number'] ?? '').toString(),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry.transaction['name'] ?? '',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              transactionDate,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dateTimeFormat.format(entry.printTime),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              printTypeText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransaction(BuildContext context, PrintLogEntry entry) {
    try {
      final transactionData = Map<String, dynamic>.from(entry.transaction);
      // Convert date from ISO string to DateTime if needed
      if (transactionData['date'] is String) {
        final parsed = DateTime.tryParse(transactionData['date']);
        if (parsed != null) {
          transactionData['date'] = parsed;
        }
      }
      final transaction = Transaction.fromMap(transactionData);
      showReadOnlyTransaction(context, transaction);
    } catch (e) {
      // silently ignore if transaction data is corrupted
    }
  }
}
