import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportPdfMetric {
  final String label;
  final String value;

  const ReportPdfMetric({required this.label, required this.value});
}

class ReportPdfLine {
  final String title;
  final String? subtitle;
  final String? trailing;

  const ReportPdfLine({
    required this.title,
    this.subtitle,
    this.trailing,
  });
}

class ReportPdfSection {
  final String title;
  final List<ReportPdfLine> lines;

  const ReportPdfSection({required this.title, required this.lines});
}

class ReportPdfPayload {
  final String title;
  final String? subtitle;
  final String? filterSummary;
  final List<ReportPdfMetric> metrics;
  final List<ReportPdfSection> sections;

  const ReportPdfPayload({
    required this.title,
    this.subtitle,
    this.filterSummary,
    this.metrics = const [],
    this.sections = const [],
  });
}

class ReportPdfService {
  static pw.Font? _cairoFont;

  static Future<pw.Font> _loadFont() async {
    final cached = _cairoFont;
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/fonts/cairo/Cairo.ttf');
    final font = pw.Font.ttf(data);
    _cairoFont = font;
    return font;
  }

  static Future<Uint8List> build(ReportPdfPayload payload) async {
    final font = await _loadFont();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    final generatedAt = DateTime.now();
    final date =
        '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 32),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: _text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _text(
                    payload.title,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  if (payload.subtitle?.trim().isNotEmpty == true) ...[
                    pw.SizedBox(height: 4),
                    _text(
                      payload.subtitle!,
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ],
                  if (payload.filterSummary?.trim().isNotEmpty == true) ...[
                    pw.SizedBox(height: 5),
                    _text(payload.filterSummary!, fontSize: 10),
                  ],
                  pw.SizedBox(height: 5),
                  _text(
                    'تاريخ إنشاء التقرير: $date',
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ];

          if (payload.metrics.isNotEmpty) {
            widgets.add(
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: payload.metrics
                    .map(
                      (metric) => pw.Container(
                        width: 122,
                        padding: const pw.EdgeInsets.all(9),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            _text(
                              metric.value,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            pw.SizedBox(height: 2),
                            _text(
                              metric.label,
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
            widgets.add(pw.SizedBox(height: 14));
          }

          for (final section in payload.sections) {
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                child: _text(
                  section.title,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 5));

            if (section.lines.isEmpty) {
              widgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  child: _text(
                    'لا توجد بيانات.',
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              );
            } else {
              for (final line in section.lines) {
                widgets.add(_line(line));
              }
            }
            widgets.add(pw.SizedBox(height: 12));
          }

          return widgets;
        },
      ),
    );

    return document.save();
  }

  static Future<void> share({
    required ReportPdfPayload payload,
    required String fileName,
  }) async {
    final bytes = await build(payload);
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static Future<void> printReport(ReportPdfPayload payload) async {
    final bytes = await build(payload);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _line(ReportPdfLine line) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 5),
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (line.trailing?.trim().isNotEmpty == true) ...[
            pw.Container(
              constraints: const pw.BoxConstraints(maxWidth: 90),
              child: _text(
                line.trailing!,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(width: 8),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _text(
                  line.title,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                if (line.subtitle?.trim().isNotEmpty == true) ...[
                  pw.SizedBox(height: 3),
                  _text(
                    line.subtitle!,
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Text _text(
    String value, {
    double fontSize = 10,
    pw.FontWeight? fontWeight,
    PdfColor? color,
  }) {
    return pw.Text(
      value,
      textDirection: pw.TextDirection.rtl,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }
}
