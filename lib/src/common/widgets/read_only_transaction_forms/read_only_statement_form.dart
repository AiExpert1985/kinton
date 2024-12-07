import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/generated/l10n.dart';
import 'package:tablets/src/common/values/gaps.dart';
import 'package:tablets/src/common/widgets/read_only_transaction_forms/read_only_form_field.dart';
import 'package:tablets/src/common/widgets/read_only_transaction_forms/read_only_item_list.dart';
import 'package:tablets/src/features/settings/controllers/settings_form_data_notifier.dart';
import 'package:tablets/src/features/settings/view/settings_keys.dart';
import 'package:tablets/src/features/transactions/model/transaction.dart';

// used for gifts and damages items
class ReadOnlyStatementTransaction extends ConsumerWidget {
  const ReadOnlyStatementTransaction(this.transaction, {this.isGift = false, super.key});

  final Transaction transaction;
  final bool isGift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsController = ref.read(settingsFormDataProvider.notifier);
    final hideTransactionAmountAsText =
        settingsController.getProperty(hideTransactionAmountAsTextKey);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGift) _buildFirstRow(context, transaction),
            VerticalGap.m,
            _buildSecondRow(context, transaction),
            VerticalGap.m,
            _buildThirdRow(context, transaction),
            VerticalGap.m,
            _buildFourthRow(context, transaction, hideTransactionAmountAsText),
            VerticalGap.m,
            buildReadOnlyItemList(context, transaction, true, true),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstRow(BuildContext context, Transaction transaction) {
    final nameLabel = S.of(context).customer;
    final salesmanLabel = S.of(context).transaction_salesman;
    return Row(
      children: [
        readOnlyTextFormField(transaction.name, label: nameLabel),
        HorizontalGap.l,
        readOnlyTextFormField(transaction.salesman, label: salesmanLabel),
      ],
    );
  }

  Widget _buildSecondRow(BuildContext context, Transaction transaction) {
    final numberLabel = S.of(context).transaction_number;
    final dateLabel = S.of(context).transaction_date;
    return Row(
      children: [
        readOnlyTextFormField(transaction.number, label: numberLabel),
        HorizontalGap.l,
        readOnlyTextFormField(transaction.currency, label: dateLabel),
      ],
    );
  }

  Widget _buildThirdRow(BuildContext context, Transaction transaction) {
    final notesLabel = S.of(context).transaction_notes;
    return Row(
      children: [
        readOnlyTextFormField(transaction.notes, label: notesLabel),
      ],
    );
  }

  Widget _buildFourthRow(
      BuildContext context, Transaction transaction, bool hideTransactionAmountAsText) {
    final totalAsTextlLabel = S.of(context).transaction_total_amount_as_text;
    return Visibility(
      visible: !hideTransactionAmountAsText,
      child: Row(
        children: [
          readOnlyTextFormField(transaction.totalAsText, label: totalAsTextlLabel),
        ],
      ),
    );
  }
}
