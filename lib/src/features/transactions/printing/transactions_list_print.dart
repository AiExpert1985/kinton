import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/generated/l10n.dart';
import 'package:tablets/src/common/functions/user_messages.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/printing/print_document.dart';
import 'package:tablets/src/common/values/transactions_common_values.dart';
import 'package:tablets/src/features/transactions/controllers/transaction_quick_filter_controller.dart';
import 'package:tablets/src/features/transactions/controllers/transaction_screen_controller.dart';
import 'package:tablets/src/features/transactions/controllers/transaction_screen_data_notifier.dart';

// Index of the amount column inside the row lists built below, kept in sync
// with _reportListTitles order, used to total the printed amounts.
const _amountColumnIndex = 5;

/// Prints whatever transactions are currently shown on the transactions main
/// screen (i.e. respecting all active quick filters and sorting), as an
/// organized A4 portrait report - reusing the existing report PDF pipeline
/// (printReport / getReportPdf) unchanged.
Future<void> printFilteredTransactionsList(
    BuildContext context, WidgetRef ref) async {
  final screenDataNotifier = ref.read(transactionScreenDataNotifier.notifier);
  final screenData = screenDataNotifier.data;

  if (screenData.isEmpty) {
    failureUserMessage(context, S.of(context).no_data_available);
    return;
  }

  final listTitles = _reportListTitles(context);
  final reportData = <List<dynamic>>[];
  num totalAmount = 0;
  for (final row in screenData) {
    final amount = (row[transactionTotalAmountKey] ?? 0) as num;
    totalAmount += amount;
    reportData.add([
      row[transactionTypeKey] ?? '',
      row[transactionNumberKey] ?? '',
      row[transactionDateKey]?.toDate(),
      row[transactionNameKey] ?? '',
      row[transactionSalesmanKey] ?? '',
      amount,
      row[transactionNotesKey] ?? '',
    ]);
  }

  final summaryList = List<String>.generate(listTitles.length, (_) => '');
  summaryList[0] = S.of(context).total;
  summaryList[_amountColumnIndex] = doubleToStringWithComma(totalAmount);

  final activeFiltersSummary = _activeFiltersSummary(context, ref);

  if (!context.mounted) return;
  await printReport(
    context,
    ref,
    reportData,
    S.of(context).printing_transactions,
    listTitles,
    null,
    null,
    summaryList,
    activeFiltersSummary,
    const [],
    const [],
  );
}

List<String> _reportListTitles(BuildContext context) {
  return [
    S.of(context).transaction_type,
    S.of(context).transaction_number,
    S.of(context).transaction_date,
    S.of(context).transaction_name,
    S.of(context).salesman_selection,
    S.of(context).transaction_amount,
    S.of(context).notes,
  ];
}

// builds a human readable summary of the quick filters currently active on
// the transactions screen (e.g. "نوع التعامل: قائمة بيع"), so the printed
// report shows exactly what was filtered on screen.
List<String> _activeFiltersSummary(BuildContext context, WidgetRef ref) {
  final activeFilters = ref.read(transactionQuickFiltersProvider);
  final summary = <String>[];
  for (final filter in activeFilters) {
    final value = filter.value;
    if (value == null || value.toString().trim().isEmpty) continue;
    final label = _filterLabel(context, filter.property);
    final displayValue = _filterDisplayValue(context, filter.property, value);
    summary.add('$label: $displayValue');
  }
  return summary;
}

String _filterLabel(BuildContext context, String property) {
  if (property == transactionTypeKey) return S.of(context).transaction_type;
  if (property == transactionNumberKey) return S.of(context).transaction_number;
  if (property == transactionDateKey) return S.of(context).transaction_date;
  if (property == transactionNameKey) return S.of(context).transaction_name;
  if (property == transactionSalesmanKey) return S.of(context).salesman_selection;
  if (property == transactionTotalAmountKey) return S.of(context).transaction_amount;
  if (property == isPrintedKey) return S.of(context).print_status;
  if (property == transactionNotesKey) return S.of(context).notes;
  return property;
}

String _filterDisplayValue(BuildContext context, String property, dynamic value) {
  if (property == isPrintedKey) {
    return value == true ? S.of(context).printed : S.of(context).not_printed;
  }
  if (value is DateTime) return formatDate(value);
  return value.toString();
}
