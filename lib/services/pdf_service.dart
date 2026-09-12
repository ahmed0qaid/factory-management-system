import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static Future<Uint8List> generatePayslip({
    required String employeeName,
    required String employeeNumber,
    required String jobTitle,
    required String period,
    required num baseSalary,
    required num monthlyBonus,
    required num monthlyEntitlement,
    required num overtimeAmount,
    required num allowances,
    required num bonuses,
    required num absenceDeductions,
    required num lateDeductions,
    required num penaltiesAmount,
    required num advanceInstallments,
    required num otherDeductions,
    required num netSalary,
    required String issueDate,
  }) async {
    final pdf = pw.Document();

    // Use Cairo font which supports Arabic
    final fontData = await rootBundle.load('assets/fonts/cairo/Cairo.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load('assets/fonts/cairo/Cairo.ttf');
    final fontBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl, // Important for Arabic
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'كشف راتب موظف',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('اسم الموظف: $employeeName'),
                        pw.Text('رقم الموظف: $employeeNumber'),
                        pw.Text('المسمى الوظيفي: $jobTitle'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('الفترة: $period'),
                        pw.Text('تاريخ الإصدار: $issueDate'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'تفاصيل الاستحقاقات',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.normal,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Divider(),
                _buildRow('الراتب الأساسي', baseSalary),
                _buildRow('المكافأة الشهرية', monthlyBonus),
                _buildRow(
                  'المستحق الشهري الأساسي',
                  monthlyEntitlement,
                  isBold: true,
                ),
                _buildRow('البدلات', allowances),
                _buildRow('المكافآت الإضافية', bonuses),
                _buildRow('العمل الإضافي', overtimeAmount),
                pw.SizedBox(height: 20),
                pw.Text(
                  'تفاصيل الاستقطاعات',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.normal,
                    color: PdfColors.red800,
                  ),
                ),
                pw.Divider(),
                _buildRow('خصم الغياب', absenceDeductions),
                _buildRow('خصم التأخير', lateDeductions),
                _buildRow('الجزاءات', penaltiesAmount),
                _buildRow('خصم السلف', advanceInstallments),
                _buildRow('استقطاعات أخرى', otherDeductions),
                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'صافي الراتب',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      ),
                      pw.Text(
                        '${netSalary.toStringAsFixed(2)} ريال',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRow(String label, num value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '${value.toStringAsFixed(2)} ريال',
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
