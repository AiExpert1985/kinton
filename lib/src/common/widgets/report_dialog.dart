import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:tablets/generated/l10n.dart';
import 'package:tablets/src/common/functions/utils.dart';
import 'package:tablets/src/common/printing/print_document.dart';
import 'package:tablets/src/common/values/gaps.dart';
import 'package:tablets/src/common/widgets/custom_icons.dart';
import 'package:tablets/src/common/widgets/show_transaction_dialog.dart';

void showReportDialog(
  BuildContext context,
  List<String> columnTitles,
  List<List<dynamic>> dataList, {
  String? title,
  int? dateIndex,
  int? dropdownIndex,
  String? dropdownLabel,
  int? sumIndex,
  double targetedWidth = 1600,
  double targetedHeight = 1200,
  // if useOriginalTransaction is ture, it means first item is the orginal transaction
  // it will not be displayed in the rows of data, but used to show the orginal transaction
  // as a read only dialog when the row is pressed.
  bool useOriginalTransaction = false,
  // if isCount, means we take count, not sum
  bool isCount = false,
  int? dropdown2Index,
  String? dropdown2Label,
  int? dropdown3Index,
  String? dropdown3Label,
}) {
  showDialog(
    context: context,
    builder: (context) {
      final maxHeight = MediaQuery.of(context).size.height;
      final height = targetedHeight > maxHeight ? maxHeight : targetedHeight;
      final maxWidth = MediaQuery.of(context).size.width;
      final width = targetedWidth > maxWidth ? maxWidth : targetedWidth;
      return _DateFilterDialog(
        title: title,
        width: width,
        height: height,
        titleList: columnTitles,
        dataList: dataList,
        dateIndex: dateIndex,
        dropdownIndex: dropdownIndex,
        dropdownLabel: dropdownLabel,
        dropdown2Index: dropdown2Index,
        dropdown2Label: dropdown2Label,
        dropdown3Index: dropdown3Index,
        dropdown3Label: dropdown3Label,
        sumIndex: sumIndex,
        useOriginalTransaction: useOriginalTransaction,
        isCount: isCount,
      );
    },
  );
}

class _DateFilterDialog extends StatefulWidget {
  final double width;
  final double height;
  final List<String> titleList;
  final List<List<dynamic>> dataList;
  final String? title;
  final int? dateIndex;
  final int? dropdownIndex;
  final String? dropdownLabel;
  final int? dropdown2Index;
  final String? dropdown2Label;
  final int? dropdown3Index;
  final String? dropdown3Label;
  final int? sumIndex;
  final bool useOriginalTransaction;
  final bool isCount;
  final bool useAbsoluteNumbers;

  const _DateFilterDialog({
    required this.width,
    required this.height,
    required this.titleList,
    required this.dataList,
    this.title,
    this.dateIndex,
    this.dropdownIndex,
    this.dropdownLabel,
    this.dropdown2Index,
    this.dropdown2Label,
    this.dropdown3Index,
    this.dropdown3Label,
    this.sumIndex,
    required this.useOriginalTransaction,
    required this.isCount,
    // ignore: unused_element
    this.useAbsoluteNumbers = false,
  });

  @override
  __DateFilterDialogState createState() => __DateFilterDialogState();
}

class __DateFilterDialogState extends State<_DateFilterDialog> {
  DateTime? startDate;
  DateTime? endDate;
  List<String> selectedDropdownValues = [];
  List<String> selectedDropdown2Values = [];
  List<String> selectedDropdown3Values = [];
  List<List<dynamic>> filteredList = [];
  List<String> dropdownValues = [];
  List<String> dropdown2Values = [];
  List<String> dropdown3Values = [];

  @override
  void initState() {
    if (widget.dateIndex != null) {
      sortListOfListsByDate(widget.dataList, widget.dateIndex!, isAscending: true);
    }
    super.initState();
    if (widget.dropdownIndex != null) {
      dropdownValues = widget.dataList
          .map((item) => item[widget.dropdownIndex!].toString()) // Map to the value at index 1
          .toSet() // Convert to a Set to ensure uniqueness
          .toList(); // Convert back to a List<String>
    }
    if (widget.dropdown2Index != null) {
      dropdown2Values = widget.dataList
          .map((item) => item[widget.dropdown2Index!].toString()) // Map to the value at index 1
          .toSet() // Convert to a Set to ensure uniqueness
          .toList(); // Convert back to a List<String>
    }
    if (widget.dropdown3Index != null) {
      dropdown3Values = widget.dataList
          .map((item) => item[widget.dropdown3Index!].toString()) // Map to the value at index 1
          .toSet() // Convert to a Set to ensure uniqueness
          .toList(); // Convert back to a List<String>
    }

    filteredList = List.from(widget.dataList);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.title != null) _buildTitle(),
            VerticalGap.xl,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (widget.dateIndex != null) Expanded(child: _buildDateSelectionRow()),
                if (widget.dropdownIndex != null) HorizontalGap.xl,
                if (widget.dropdownIndex != null) Expanded(child: _buildMultiSelectDropdown()),
                if (widget.dropdown2Index != null) HorizontalGap.xl,
                if (widget.dropdown2Index != null) Expanded(child: _buildMultiSelectDropdown2()),
                if (widget.dropdown3Index != null) HorizontalGap.xl,
                if (widget.dropdown3Index != null) Expanded(child: _buildMultiSelectDropdown3()),
              ],
            )
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildListTitles(),
            _buildDataList(context),
            if (widget.sumIndex != null) _buildSumDisplay(),
            if (widget.isCount) _buildCountDisplay(),
          ],
        ),
      ),
      actions: _buildButtons(filteredList, widget.title, widget.titleList, startDate, endDate),
    );
  }

  void _filterData() {
    List<List<dynamic>> newList = widget.dataList;
    // first filter on data (if not null)
    if (widget.dateIndex != null) {
      newList = newList.where((list) {
        if (list.length > widget.dateIndex!) {
          DateTime date;
          try {
            date = DateTime.parse(list[widget.dateIndex!].toString());
          } catch (e) {
            return false;
          }
          bool dateInRange =
              (startDate == null || date.isAfter(startDate!.subtract(const Duration(days: 1)))) &&
                  (endDate == null || date.isBefore(endDate!.add(const Duration(days: 1))));
          return dateInRange;
        }
        return false;
      }).toList();
    }
    // filter the result of previous filter using first dropdown selection (if not null)
    if (widget.dropdownIndex != null) {
      newList = newList.where((list) {
        String cellValue = list[widget.dropdownIndex!].toString();
        bool test = selectedDropdownValues.isEmpty || selectedDropdownValues.contains(cellValue);
        return test;
      }).toList();
    }
    // filter the result of previous filter using first dropdown2 selection (if not null)
    if (widget.dropdown2Index != null) {
      newList = newList.where((list) {
        String cellValue = list[widget.dropdown2Index!].toString();
        bool test = selectedDropdown2Values.isEmpty || selectedDropdown2Values.contains(cellValue);
        return test;
      }).toList();
    }
    // filter the result of previous filter using first dropdown3 selection (if not null)
    if (widget.dropdown3Index != null) {
      newList = newList.where((list) {
        String cellValue = list[widget.dropdown3Index!].toString();
        bool test = selectedDropdown3Values.isEmpty || selectedDropdown3Values.contains(cellValue);
        return test;
      }).toList();
    }

    setState(() {
      filteredList = [...newList];
    });
  }

  Widget _buildDateSelectionRow() {
    return Row(
      children: [
        _buildCancelButton(startDate, () {
          setState(() {
            startDate = null;
          });
          _filterData();
        }),
        _buildDatePicker('start_date', startDate, S.of(context).from_date, (value) {
          setState(() {
            startDate = value;
          });
          _filterData();
        }),
        HorizontalGap.l,
        _buildCancelButton(endDate, () {
          setState(() {
            endDate = null;
          });
          _filterData();
        }),
        _buildDatePicker('end_date', endDate, S.of(context).to_date, (value) {
          setState(() {
            endDate = value;
          });
          _filterData();
        }),
      ],
    );
  }

  Widget _buildMultiSelectDropdown() {
    return MultiSelectDialogField(
      separateSelectedItems: false,
      dialogHeight: dropdownValues.length * 60,
      dialogWidth: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey), // Border color
        borderRadius: BorderRadius.circular(4.0), // Rounded corners
      ),
      confirmText: Text(S.of(context).select),
      cancelText: Text(S.of(context).cancel),
      items: dropdownValues.map((String value) => MultiSelectItem<String>(value, value)).toList(),
      title: Text(widget.dropdownLabel ?? ''),
      buttonText: Text(
        widget.dropdownLabel ?? '',
        style: const TextStyle(color: Colors.black26, fontSize: 15),
      ),
      onConfirm: (List<String> values) {
        setState(() {
          selectedDropdownValues = values;
        });
        _filterData();
      },
      initialValue: selectedDropdownValues,
      searchable: true,
    );
  }

  Widget _buildMultiSelectDropdown2() {
    return MultiSelectDialogField(
      separateSelectedItems: false,
      dialogHeight: dropdown2Values.length * 60,
      dialogWidth: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey), // Border color
        borderRadius: BorderRadius.circular(4.0), // Rounded corners
      ),
      confirmText: Text(S.of(context).select),
      cancelText: Text(S.of(context).cancel),
      items: dropdown2Values.map((String value) => MultiSelectItem<String>(value, value)).toList(),
      title: Text(widget.dropdown2Label ?? ''),
      buttonText: Text(
        widget.dropdown2Label ?? '',
        style: const TextStyle(color: Colors.black26, fontSize: 15),
      ),
      onConfirm: (List<String> values) {
        setState(() {
          selectedDropdown2Values = values;
        });
        _filterData();
      },
      initialValue: selectedDropdown2Values,
      searchable: true,
    );
  }

  Widget _buildMultiSelectDropdown3() {
    return MultiSelectDialogField(
      separateSelectedItems: false,
      dialogHeight: dropdown3Values.length * 60,
      dialogWidth: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey), // Border color
        borderRadius: BorderRadius.circular(4.0), // Rounded corners
      ),
      confirmText: Text(S.of(context).select),
      cancelText: Text(S.of(context).cancel),
      items: dropdown3Values.map((String value) => MultiSelectItem<String>(value, value)).toList(),
      title: Text(widget.dropdown3Label ?? ''),
      buttonText: Text(
        widget.dropdown3Label ?? '',
        style: const TextStyle(color: Colors.black26, fontSize: 15),
      ),
      onConfirm: (List<String> values) {
        setState(() {
          selectedDropdown3Values = values;
        });
        _filterData();
      },
      initialValue: selectedDropdown3Values,
      searchable: true,
    );
  }

  Widget _buildDatePicker(
      String name, DateTime? initialValue, String labelText, ValueChanged<DateTime?> onChanged) {
    return Expanded(
      child: FormBuilderDateTimePicker(
        textAlign: TextAlign.center,
        name: name,
        decoration: InputDecoration(
          labelStyle: const TextStyle(color: Colors.black26, fontSize: 15),
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        initialValue: initialValue,
        inputType: InputType.date,
        format: DateFormat('dd-MM-yyyy'),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCancelButton(DateTime? date, VoidCallback onPressed) {
    return Visibility(
      visible: date != null,
      child: IconButton(
        icon: const Icon(Icons.clear, size: 15, color: Colors.red),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildListTitles() {
    return _buildRowContrainer(
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: widget.titleList.map((item) {
          return SizedBox(
            width: widget.width / widget.titleList.length,
            child: Text(item,
                style:
                    const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDataList(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      width: widget.width,
      height: widget.height * 0.5, // Set a fixed height for the list
      child: ListView.builder(
        itemCount: filteredList.length,
        // separatorBuilder: (context, index) => const Divider(thickness: 0.5, color: Colors.grey),
        itemBuilder: (context, index) {
          final data = filteredList[index];
          Widget displayedWidget = widget.useOriginalTransaction
              ? InkWell(
                  child: _buildDataRow(context, data),
                  onTap: () {
                    if (widget.useOriginalTransaction) {
                      // if useOriginalTransaction the, first item is alway the orginal transaction
                      showReadOnlyTransaction(context, data[0]);
                    }
                  },
                )
              : _buildDataRow(context, data);
          return displayedWidget;
        },
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, List<dynamic> data) {
    // if useOriginalTransaction is true, it means first item is Transaction
    // we don't want to display it, we want to used it as a button that show
    // a read only transaction dialog
    final itemsToDisplay = widget.useOriginalTransaction
        ? data.sublist(1, data.length) // Exclude the last item
        : data;
    // I want to highlight rows that represent a receipt with red text color
    bool isHilighted = false;
    for (var cell in data) {
      if (cell is String &&
          (cell.contains(S.of(context).transaction_type_customer_receipt) ||
              cell.contains(S.of(context).transaction_type_customer_return))) {
        isHilighted = true;
        break;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: itemsToDisplay.map((item) {
        if (item is DateTime) item = formatDate(item);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(border: Border.all(width: 0.2)),
          width: widget.width / widget.titleList.length,
          child: Text(
              item is String
                  ? item
                  : doubleToStringWithComma(item, isAbsoluteValue: widget.useAbsoluteNumbers),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isHilighted ? Colors.red : Colors.black,
                  fontSize: 16)),
        );
      }).toList(),
    );
  }

  Widget _buildTitle() {
    return Container(
        padding: const EdgeInsets.all(2),
        width: 300,
        child:
            Text(textAlign: TextAlign.center, widget.title!, style: const TextStyle(fontSize: 20)));
  }

  Widget _buildSumDisplay() {
    double sum = 0;
    for (var item in filteredList) {
      if (item.length > widget.sumIndex!) {
        sum += item[widget.sumIndex!]?.toDouble() ?? 0;
      }
    }
    return _buildRowContrainer(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 70.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(S.of(context).total,
                style: const TextStyle(
                    fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
            Text(doubleToStringWithComma(sum),
                style:
                    const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }

  Widget _buildCountDisplay() {
    int count = filteredList.length;

    return _buildRowContrainer(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 70.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(S.of(context).count,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(doubleToStringWithComma(count.toDouble()),
                style:
                    const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))
          ],
        ),
      ),
    );
  }

  List<Widget> _buildButtons(List<List<dynamic>> reportData, String? reportTitle,
      List<String> listTitles, DateTime? startDate, DateTime? endDate) {
    final startDateString = startDate != null ? formatDate(startDate) : null;
    final endDateString = endDate != null ? formatDate(endDate) : null;
    return <Widget>[
      Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PrintReportButton(reportData, reportTitle ?? '', listTitles, startDateString,
                endDateString, widget.sumIndex, widget.isCount, widget.useOriginalTransaction),
            HorizontalGap.m,
            IconButton(
              icon: const ShareIcon(),
              onPressed: () {
                // TODO: Implement share functionality
              },
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildRowContrainer(Widget childWidget) {
    return Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        decoration: BoxDecoration(
            color: const Color.fromARGB(255, 227, 240, 247),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade300)),
        child: childWidget);
  }
}

class PrintReportButton extends ConsumerWidget {
  const PrintReportButton(this.reportData, this.reportTitle, this.listTitles, this.startDate,
      this.endDate, this.sumIndex, this.isCount, this.useOriginalTransaction,
      {super.key});

  final List<List<dynamic>> reportData;
  final String reportTitle;
  final String? startDate;
  final String? endDate;
  final List<String> listTitles;
  final int? sumIndex;
  final bool isCount;
  final bool useOriginalTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String summaryTitle = isCount ? S.of(context).count : S.of(context).total;

    //if transaction is included, then we don't print it because it is only intended to show original transaction
    List<List<dynamic>> printingData = [...reportData];
    if (useOriginalTransaction) {
      printingData = removeIndicesFromInnerLists(reportData, [0]);
    }

    return IconButton(
      icon: const PrintIcon(),
      onPressed: () {
        num summaryValue = 0;
        if (isCount) {
          summaryValue = reportData.length;
        } else if (sumIndex != null) {
          for (var item in reportData) {
            if (item[sumIndex!] is num || item[sumIndex!] is int || item[sumIndex!] is double) {
              summaryValue += item[sumIndex!]?.toDouble() ?? 0;
            }
          }
        }
        printReport(context, ref, printingData, reportTitle, listTitles, startDate, endDate,
            summaryValue, summaryTitle);
      },
    );
  }
}
