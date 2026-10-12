import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class PdfBridgePlugin extends Plugin {
  @override
  String get name => 'pdf';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'PDF generate, view, print plugin';

  @override
  List<String> get supportedMethods => [
        'generateFromText',
        'generateFromHtml',
        'print',
        'share',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'generateFromText':
        return _generateFromText(args);
      case 'generateFromHtml':
        return _generateFromHtml(args);
      case 'print':
        return _print(args);
      case 'share':
        return _share(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _generateFromText(
      Map<String, dynamic> args) async {
    final text = args['text'] as String;
    final title = args['title'] as String? ?? 'Document';
    final fileName = args['fileName'] as String? ??
        'doc_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final fontSize = (args['fontSize'] as num?)?.toDouble() ?? 12;

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.Paragraph(
            text: text,
            style: pw.TextStyle(fontSize: fontSize),
          ),
        ],
      ),
    );

    return _saveDoc(doc, fileName);
  }

  Future<Map<String, dynamic>> _generateFromHtml(
      Map<String, dynamic> args) async {
    final html = args['html'] as String;
    final fileName = args['fileName'] as String? ??
        'doc_${DateTime.now().millisecondsSinceEpoch}.pdf';

    // html to pdf conversion via printing
    // ignore: deprecated_member_use -- Printing.convertHtml has no replacement in printing 5.x
    final bytes = await Printing.convertHtml(
      html: html,
      format: PdfPageFormat.a4,
    );

    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(p.join(dir.path, 'pdfs'));
    await pdfDir.create(recursive: true);

    final file = File(p.join(pdfDir.path, fileName));
    await file.writeAsBytes(bytes);

    return {
      'generated': true,
      'path': file.path,
      'fileName': fileName,
      'size': bytes.length,
    };
  }

  Future<Map<String, dynamic>> _print(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final html = args['html'] as String?;
    final name = args['name'] as String? ?? 'Document';

    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (!await file.exists()) {
        return {'printed': false, 'reason': 'file_not_found'};
      }
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        name: name,
        onLayout: (format) async => bytes,
      );
    } else if (html != null && html.isNotEmpty) {
      await Printing.layoutPdf(
        name: name,
        onLayout: (format) async {
          // ignore: deprecated_member_use -- Printing.convertHtml has no replacement in printing 5.x
          return await Printing.convertHtml(
            html: html,
            format: format,
          );
        },
      );
    } else {
      return {'printed': false, 'reason': 'no_source'};
    }

    return {'printed': true};
  }

  Future<Map<String, dynamic>> _share(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final file = File(path);

    if (!await file.exists()) {
      return {'shared': false, 'reason': 'file_not_found'};
    }

    final bytes = await file.readAsBytes();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: p.basename(path),
    );

    return {'shared': true, 'path': path};
  }

  Future<Map<String, dynamic>> _saveDoc(
      pw.Document doc, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(p.join(dir.path, 'pdfs'));
    await pdfDir.create(recursive: true);

    final bytes = await doc.save();
    final file = File(p.join(pdfDir.path, fileName));
    await file.writeAsBytes(bytes);

    BridgeLogger.info('PDF', 'Generated: ${file.path} (${bytes.length} bytes)');

    return {
      'generated': true,
      'path': file.path,
      'fileName': fileName,
      'size': bytes.length,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'generateFromText':
        if (args['text'] is! String || (args['text'] as String).isEmpty) {
          return ValidationResult.invalid('text is required');
        }
        return ValidationResult.valid();

      case 'generateFromHtml':
        if (args['html'] is! String || (args['html'] as String).isEmpty) {
          return ValidationResult.invalid('html is required');
        }
        return ValidationResult.valid();

      case 'share':
        if (args['path'] is! String || (args['path'] as String).isEmpty) {
          return ValidationResult.invalid('path is required');
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
