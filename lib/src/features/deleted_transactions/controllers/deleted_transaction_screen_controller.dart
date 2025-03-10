import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/interfaces/screen_controller.dart';
import 'package:tablets/src/common/providers/screen_data_notifier.dart';
import 'package:tablets/src/features/deleted_transactions/controllers/deleted_transaction_screen_data_notifier.dart';
import 'package:tablets/src/features/deleted_transactions/repository/deleted_transaction_db_cache_provider.dart';
import 'package:tablets/src/common/classes/db_cache.dart';
import 'package:flutter/material.dart';

const String transactionTypeKey = 'transactionType';
const String transactionDateKey = 'date';
const String transactionNameKey = 'name';
const String transactionSalesmanKey = 'salesman';
const String transactionNumberKey = 'number';
const String transactionTotalAmountKey = 'totalAmount';
const String transactionNotesKey = 'notes';

final deletedTransactionScreenControllerProvider =
    Provider<DeletedTransactionScreenController>((ref) {
  final screenDataNotifier = ref.read(deletedTransactionScreenDataNotifier.notifier);
  final dbCache = ref.read(deletedTransactionDbCacheProvider.notifier);
  return DeletedTransactionScreenController(screenDataNotifier, dbCache);
});

class DeletedTransactionScreenController implements ScreenDataController {
  DeletedTransactionScreenController(
    this._screenDataNotifier,
    this._dbCache,
  );
  final ScreenDataNotifier _screenDataNotifier;
  final DbCache _dbCache;

  @override
  void setFeatureScreenData(BuildContext context) {
    final dbCacheDataCopy = deepCopyDbCache(_dbCache.data);
    _screenDataNotifier.initialize({});
    for (var mapData in dbCacheDataCopy) {
      mapData[transactionTypeKey] =
          translateDbTextToScreenText(context, mapData[transactionTypeKey]);
    }
    // I want the initial display of screen data to be ordered on time to recent to oldest
    sortMapsByProperty(dbCacheDataCopy, 'deleteDateTime');
    _screenDataNotifier.set(dbCacheDataCopy);
  }

  /// create a list of lists, where each resulting list contains transaction info
  /// [type, number, date, totalQuantity, totalProfit, totalSalesmanCommission, ]
  @override
  Map<String, dynamic> getItemScreenData(
      BuildContext context, Map<String, dynamic> transactionData) {
    final dbRef = transactionData['dbRefKey'];
    return _dbCache.getItemByDbRef(dbRef);
  }
}
