import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tablets/src/common/functions/debug_print.dart';
import 'package:tablets/src/common/functions/file_system_path.dart';
import 'package:tablets/src/common/printing/customer_invoice_pdf.dart';
import 'package:tablets/src/common/printing/customer_return.dart';
import 'package:tablets/src/common/printing/expendure_pdf.dart';
import 'package:tablets/src/common/printing/vendor_receipt_pdf.dart';
import 'package:tablets/src/common/values/constants.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:tablets/src/features/settings/controllers/settings_form_data_notifier.dart';

const darkBgColor = PdfColor(0.2, 0.2, 0.5);
const lightBgColor = PdfColor(0.85, 0.85, 0.99);
const bordersColor = PdfColors.grey;
const labelsColor = PdfColors.red;

Future<void> _printPDf(Document pdf, int numCopies, bool isLandScape) async {
  try {
    for (int i = 0; i < numCopies; i++) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          // Return the PDF document as bytes
          return await pdf.save();
        },
        format: isLandScape
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4.portrait, // Specify A4 landscape format
      );
    }
  } catch (e) {
    debugLog('Printing failed - ($e)');
  }
}

Future<void> printDocument(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> transactionData,
) async {
  try {
    final settings = ref.read(settingsFormDataProvider.notifier);
    final settingInvoiceCopies = settings.data['printedCustomerInvoices'];
    final numCopies = transactionData['transactionType'].contains('Receipt') ||
            transactionData['transactionType'].contains('expenditure')
        ? 1
        : settingInvoiceCopies;
    final isLandScape = transactionData['transactionType'].contains('Receipt') ? true : false;
    final image = await loadImage('assets/images/invoice_logo.PNG');
    final filePath = gePdfpath('test_file');
    if (context.mounted) {
      final pdf = await getPdfFile(context, ref, transactionData, image);
      if (filePath == null) return;

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      _printPDf(pdf, numCopies, isLandScape);
    }
  } catch (e) {
    debugLog('Pdf creation failed - ($e)');
  }
}

Future<pw.ImageProvider> loadImage(String path) async {
  final ByteData bytes = await rootBundle.load(path);
  final Uint8List list = bytes.buffer.asUint8List();
  return pw.MemoryImage(list);
}

Future<Document> getPdfFile(BuildContext context, WidgetRef ref,
    Map<String, dynamic> transactionData, pw.ImageProvider image) async {
  // now we only print customer invoices
  if (transactionData['transactionType'] == TransactionType.customerInvoice.name) {
    return getCustomerInvoicePdf(context, ref, transactionData, image);
  } else if (transactionData['transactionType'] == TransactionType.customerReceipt.name) {
  } else if (transactionData['transactionType'] == TransactionType.vendorReceipt.name) {
    return getVendorReceiptPdf(context, ref, transactionData, image);
  } else if (transactionData['transactionType'] == TransactionType.expenditures.name) {
    return getExpenditurePdf(context, ref, transactionData, image);
  } else if (transactionData['transactionType'] == TransactionType.customerReturn.name) {
    return getCustomerReturnPdf(context, ref, transactionData, image);
  }
  return getEmptyPdf();
}

Future<Document> getEmptyPdf() async {
  final pdf = pw.Document();
  pdf.addPage(pw.Page(
      margin: pw.EdgeInsets.zero,
      build: (pw.Context ctx) {
        return pw.Text('Empty page');
      }));
  return pdf;
}

pw.Widget arabicText(
  Font arabicFont,
  String text, {
  PdfColor? textColor,
  double? width,
  bool isTitle = false,
  double fontSize = 10,
  PdfColor? bgColor,
  PdfColor? borderColor,
  bool isBordered = false,
}) {
  return pw.Container(
    width: width,
    decoration: isBordered
        ? pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(Radius.circular(1)), // Rounded corners
            border: pw.Border.all(color: borderColor ?? PdfColors.grey600), // Border color
          )
        : null,
    color: bgColor,
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      textDirection: pw.TextDirection.rtl,
      style: pw.TextStyle(
        font: arabicFont,
        fontSize: fontSize,
        color: textColor,
      ),
    ),
  );
}

pw.Widget footerBar(
  Font arabicFont,
  String text1,
  String text2,
) {
  final childWidget = pw.Row(
    children: [
      pw.SizedBox(width: 14),
      arabicText(arabicFont, text2, fontSize: 8, textColor: PdfColors.white),
      pw.Spacer(),
      arabicText(arabicFont, text1, fontSize: 8, textColor: PdfColors.white),
      pw.SizedBox(width: 14),
    ],
  );
  return coloredContainer(childWidget, 555, height: 22, bgColor: darkBgColor);
}

pw.Widget coloredContainer(pw.Widget childWidget, double width,
    {bool isDecorated = true,
    PdfColor bgColor = PdfColors.white,
    PdfColor borderColor = PdfColors.grey300,
    double height = 22}) {
  return pw.Container(
    width: width,
    height: height, // Increased height to provide more space for the label
    decoration: isDecorated
        ? pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(Radius.circular(4)), // Rounded corners
            border: pw.Border.all(color: borderColor), // Border color
            color: bgColor,
          )
        : null,
    padding: const pw.EdgeInsets.only(bottom: 0, left: 0), // Set padding to 0 to avoid extra space
    child: childWidget,
  );
}

pw.Widget labedContainer(String text, String label, Font arabicFont,
    {PdfColor bgColor = PdfColors.white,
    PdfColor borderColor = PdfColors.grey,
    double width = 170,
    double height = 22}) {
  final childWidget = arabicText(arabicFont, text);
  // return pw.Stack(children: [
  return pw.Stack(children: [
    pw.Container(
      padding: const pw.EdgeInsets.only(top: 17),
      child: coloredContainer(childWidget, width,
          height: height, bgColor: bgColor, borderColor: borderColor),
    ),
    pw.Positioned(
      top: 3, // Adjusted position to move the label down
      right: 5, // Position at the right
      child: arabicText(arabicFont, label,
          textColor: PdfColors.red, fontSize: 7, bgColor: PdfColors.white),
    ),
  ]);
}

pw.Widget separateLabelContainer(Font arabicFont, String content, String label, double width) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.center,
    children: [
      coloredContainer(arabicText(arabicFont, content), width),
      pw.SizedBox(width: 10),
      arabicText(arabicFont, label, textColor: PdfColors.red)
    ],
  );
}