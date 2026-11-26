import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Builds a one-page PDF invoice for an order.
Future<Uint8List> buildInvoice(Map o) async {
  final doc = pw.Document(title: 'AgriSphere invoice #${o['number']}', author: 'AgriSphere');
  final green = PdfColor.fromHex('#16803C');
  final items = ((o['items'] as List?) ?? const []).cast<Map>();
  String money(num n) => rs(n).replaceFirst('Rs ', 'Rs. ');
  final created = DateTime.tryParse('${o['createdAt'] ?? ''}')?.toLocal() ?? DateTime.now();
  final payLabel = {
        'cod_pending': 'Cash on Delivery (due)',
        'awaiting_proof': 'Awaiting payment',
        'under_review': 'Payment under review',
        'paid': 'PAID',
        'rejected': 'Payment rejected',
      }['${o['paymentStatus']}'] ??
      '${o['paymentStatus'] ?? ''}';

  pw.Widget kv(String k, String v, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(k, style: pw.TextStyle(color: PdfColors.grey700, fontWeight: bold ? pw.FontWeight.bold : null))),
          pw.Text(v, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null, fontSize: bold ? 13 : 11)),
        ]),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('AgriSphere', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: green)),
            pw.Text('Farm-to-market platform', style: const pw.TextStyle(color: PdfColors.grey700)),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text('#${o['number']}'),
          pw.Text('${created.day}/${created.month}/${created.year}', style: const pw.TextStyle(color: PdfColors.grey700)),
        ]),
      ]),
      pw.SizedBox(height: 24),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Bill to', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: green)),
            pw.Text('${o['receiverName'] ?? o['buyerName'] ?? ''}'),
            if ('${o['phone'] ?? ''}'.isNotEmpty) pw.Text('${o['phone']}'),
            pw.Text('${o['address'] ?? ''}'),
          ]),
        ),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Sold by', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: green)),
            pw.Text('${o['sellerName'] ?? ''}'),
            pw.Text('Delivery: ${o['deliveryType'] == 'express' ? 'Express' : 'Standard'}'),
            pw.Text('Status: ${o['status']}'),
          ]),
        ),
      ]),
      pw.SizedBox(height: 20),
      pw.TableHelper.fromTextArray(
        headers: ['Item', 'Qty', 'Rate', 'Amount'],
        data: items
            .map((i) => [
                  '${i['title']}',
                  '${toNum(i['qtyKg']).round()} kg',
                  money(toNum(i['pricePerKg'])),
                  money(toNum(i['qtyKg']) * toNum(i['pricePerKg'])),
                ])
            .toList(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: green),
        cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
        cellPadding: const pw.EdgeInsets.all(6),
      ),
      pw.SizedBox(height: 12),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 230,
          child: pw.Column(children: [
            kv('Subtotal', money(toNum(o['subtotal']))),
            kv('Delivery', money(toNum(o['delivery']))),
            pw.Divider(),
            kv('Total', money(toNum(o['total'])), bold: true),
          ]),
        ),
      ),
      pw.SizedBox(height: 18),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Method: ${o['payment'] == 'Cash' ? 'Cash on Delivery' : o['payment'] == 'Card' ? 'Card (via Easypaisa)' : 'Easypaisa'}'),
          pw.Text('Status: $payLabel'),
          if ('${o['paymentRef'] ?? ''}'.isNotEmpty) pw.Text('Transaction ID: ${o['paymentRef']}'),
        ]),
      ),
      pw.Spacer(),
      pw.Divider(color: PdfColors.grey300),
      pw.Text('Thank you for buying directly from farmers on AgriSphere.', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
      pw.Text('This is a computer-generated invoice.', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
    ]),
  ));
  return doc.save();
}

/// "Invoice" button: opens the system print / save-as-PDF / share dialog.
class InvoiceButton extends StatelessWidget {
  final Map order;
  const InvoiceButton({super.key, required this.order});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () async {
          try {
            final bytes = await buildInvoice(order);
            await Printing.layoutPdf(name: 'AgriSphere-invoice-${order['number']}.pdf', onLayout: (_) async => bytes);
          } catch (e) {
            if (context.mounted) snack(context, cleanErr(e), error: true);
          }
        },
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(tr('Download invoice')),
        style: OutlinedButton.styleFrom(foregroundColor: C.green, side: const BorderSide(color: C.green), minimumSize: const Size.fromHeight(46)),
      );
}
