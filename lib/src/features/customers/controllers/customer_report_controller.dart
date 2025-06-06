import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/generated/l10n.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/values/constants.dart';
import 'package:tablets/src/common/values/transactions_common_values.dart';
import 'package:tablets/src/common/widgets/report_dialog.dart';
import 'package:tablets/src/features/customers/controllers/customer_screen_controller.dart';
import 'package:tablets/src/features/customers/controllers/customer_screen_data_notifier.dart';
import 'package:tablets/src/features/customers/repository/customer_db_cache_provider.dart';
import 'package:tablets/src/features/transactions/controllers/transaction_screen_controller.dart';
import 'package:tablets/src/features/transactions/repository/transaction_db_cache_provider.dart';

final customerReportControllerProvider = Provider<CustomerReportController>((ref) {
  return CustomerReportController();
});

class CustomerReportController {
  CustomerReportController();

  void showCustomerMatchingReport(
      BuildContext context, List<List<dynamic>> transactionList, String title) {
    showReportDialog(context, _getCustomerMatchingReportTitles(context), transactionList,
        dateIndex: 3,
        title: title,
        dropdownIndex: 1,
        dropdownLabel: S.of(context).transaction_type,
        // this index is after removing first column of transaction (i.e it is accually 4)
        summaryIndexes: [3],
        useOriginalTransaction: true);
  }

  void showGiftsReport(BuildContext context, List<List<dynamic>> giftsList, String title) {
    showReportDialog(
      context,
      _getGiftsReportTitles(context),
      giftsList,
      dateIndex: 3,
      title: title,
      // this index is after removing first column of transaction (i.e it is accually 4)
      summaryIndexes: [3],
      dropdownIndex: 2,
      dropdownLabel: S.of(context).transaction_type,
      useOriginalTransaction: true,
    );
  }

  void showInvoicesReport(BuildContext context, List<List<dynamic>> invoices, String title) {
    showReportDialog(
      context,
      _getInvoiceReportTitles(context),
      invoices,
      title: title,
      // this index is after removing first column of transaction (i.e it is accually 7)
      summaryIndexes: [6],
      dateIndex: 2,
      dropdownIndex: 5,
      dropdownLabel: S.of(context).invoice_status,
      useOriginalTransaction: true,
    );
  }

  void showDueInvoicesReport(BuildContext context, List<List<dynamic>> invoices, String title) {
    showReportDialog(
      context,
      _getInvoiceReportTitles(context),
      invoices,
      title: title,
      // this index is after removing first column of transaction (i.e it is accually 8)
      summaryIndexes: [7],
      useOriginalTransaction: true,
    );
  }

  void showProfitReport(BuildContext context, List<List<dynamic>> invoices, String title) {
    showReportDialog(
      context,
      _getProfitReportTitles(context),
      invoices,
      title: title,
      // this index is after removing first column of transaction (i.e it is accually 5)
      summaryIndexes: [4],
      useOriginalTransaction: true,
      dateIndex: 2,
    );
  }

  List<String> _getCustomerMatchingReportTitles(BuildContext context) {
    return [
      S.of(context).transaction_type,
      S.of(context).transaction_number,
      S.of(context).transaction_date,
      S.of(context).transaction_amount,
      S.of(context).balance,
    ];
  }

  List<String> _getInvoiceReportTitles(BuildContext context) {
    return [
      S.of(context).transaction_number,
      S.of(context).transaction_date,
      S.of(context).transaction_amount,
      S.of(context).payment,
      S.of(context).invoice_status,
      S.of(context).invoice_close_duration,
      S.of(context).remaining_amount,
    ];
  }

  List<String> _getProfitReportTitles(BuildContext context) {
    return [
      S.of(context).transaction_number,
      S.of(context).transaction_date,
      S.of(context).transaction_amount,
      S.of(context).invoice_status,
      S.of(context).invoice_profit,
    ];
  }

  List<String> _getGiftsReportTitles(BuildContext context) {
    return [
      S.of(context).transaction_number,
      S.of(context).transaction_type,
      S.of(context).transaction_date,
      S.of(context).customer_gifts_and_discounts,
    ];
  }

  List<String> _getAllCustomersColumnTitles(BuildContext context) {
    return [
      S.of(context).customers,
      S.of(context).salesmen,
      S.of(context).regions,
      "المستحق",
      S.of(context).total_debt,
      S.of(context).last_receipt_date,
      "اخر قائمة",
    ];
  }

  void showAllCustomersDebt(BuildContext context, WidgetRef ref) {
    final screenDataController = ref.read(customerScreenControllerProvider);
    screenDataController.setFeatureScreenData(context);
    final screenDataNotifier = ref.read(customerScreenDataNotifier.notifier);
    final screenData = screenDataNotifier.data;
    final customerDbCache = ref.read(customerDbCacheProvider.notifier);

    List<List<dynamic>> debtList = [];
    for (var customerScreenData in screenData) {
      final name = customerScreenData[customerNameKey] as String;
      final customerDbCacheData = customerDbCache.getItemByProperty('name', name);
      String salesman = customerScreenData[customerSalesmanKey] as String;
      salesman = salesman.trim();
      final region = customerDbCacheData['region'] ?? '-';
      final totalDebt = customerScreenData[totalDebtKey] as double;
      final dueDebt = customerScreenData[dueDebtKey] as double;
      // only show customers with debt > 0 or debt < 0 (special case where customer has -ve balance)
      if (totalDebt != 0) {
        final lastReceiptDate = lastCustomerReceipt(context, ref, customerScreenData);
        final lastInvoiceDate = lastCustomerInvoice(context, ref, customerScreenData);
        debtList
            .add([name, salesman, region, dueDebt, totalDebt, lastReceiptDate, lastInvoiceDate]);
      }
    }

    // sort by region
    debtList.sort((a, b) {
      return a[2].compareTo(b[2]);
    });

    showReportDialog(
      context,
      _getAllCustomersColumnTitles(context),
      debtList,
      title: S.of(context).salesmen_debt_report,
      // this index is after removing first column of transaction (i.e it is accually [4, 5])
      summaryIndexes: [3, 4],
      dropdownLabel: S.of(context).customer,
      dropdownIndex: 0,
      dropdown2Label: S.of(context).salesman,
      dropdown2Index: 1,
      dropdown3Label: S.of(context).region,
      dropdown3Index: 2,
    );
  }

  String lastCustomerReceipt(BuildContext context, WidgetRef ref, dynamic customerScreenData) {
    final transactionDbCache = ref.read(transactionDbCacheProvider.notifier);
    final allTransactions = transactionDbCache.data;
    final receiptDates = [];
    for (var transaction in allTransactions) {
      if (transaction[nameDbRefKey] == customerScreenData['dbRef'] &&
          transaction[transactionTypeKey] == TransactionType.customerReceipt.name) {
        final date = transaction[dateKey];
        receiptDates.add(date is DateTime ? date : date.toDate());
      }
    }
    if (receiptDates.isNotEmpty) {
      final newestDate = receiptDates.reduce((a, b) => a.isAfter(b) ? a : b);
      return formatDate(newestDate);
    }
    return S.of(context).there_is_no_customer_receipt;
  }

  String lastCustomerInvoice(BuildContext context, WidgetRef ref, dynamic customerScreenData) {
    final transactionDbCache = ref.read(transactionDbCacheProvider.notifier);
    final allTransactions = transactionDbCache.data;
    final receiptDates = [];
    for (var transaction in allTransactions) {
      if (transaction[nameDbRefKey] == customerScreenData['dbRef'] &&
          transaction[transactionTypeKey] == TransactionType.customerInvoice.name) {
        final date = transaction[dateKey];
        receiptDates.add(date is DateTime ? date : date.toDate());
      }
    }
    if (receiptDates.isNotEmpty) {
      final newestDate = receiptDates.reduce((a, b) => a.isAfter(b) ? a : b);
      return formatDate(newestDate);
    }
    return S.of(context).there_is_no_customer_receipt;
  }
}
