import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(
            title: 'Export data',
            subtitle: 'Download your house records as CSV spreadsheets or PDF reports.',
          ),
          _sectionLabel('Finance'),
          _ExportCard(
            icon: Icons.home_outlined,
            title: 'Rent history',
            subtitle: 'All rent payments grouped by period',
            onCsv: () => _shareCsv(context, 'rent_history', _rentCsv(state)),
            onPdf: () => _sharePdf(context, 'rent_history', _rentPdf(state)),
          ),
          _ExportCard(
            icon: Icons.receipt_long_outlined,
            title: 'Bills',
            subtitle: 'All bills with per-person share breakdown',
            onCsv: () => _shareCsv(context, 'bills', _billsCsv(state)),
            onPdf: () => _sharePdf(context, 'bills', _billsPdf(state)),
          ),
          _ExportCard(
            icon: Icons.subscriptions_outlined,
            title: 'Subscriptions',
            subtitle: 'Shared subscriptions and payment splits',
            onCsv: () => _shareCsv(context, 'subscriptions', _subsCsv(state)),
            onPdf: () => _sharePdf(context, 'subscriptions', _subsPdf(state)),
          ),
          _sectionLabel('Living'),
          _ExportCard(
            icon: Icons.cleaning_services_outlined,
            title: 'Cleaning tasks',
            subtitle: 'Task roster with assignee and completion status',
            onCsv: () => _shareCsv(context, 'cleaning', _cleaningCsv(state)),
            onPdf: () => _sharePdf(context, 'cleaning', _cleaningPdf(state)),
          ),
          _sectionLabel('Full report'),
          _ExportCard(
            icon: Icons.description_outlined,
            title: 'Full house report',
            subtitle: 'Finance and cleaning data combined in one PDF',
            onPdf: () => _sharePdf(context, 'house_report', _fullPdf(state)),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );

  // ── CSV builders ──────────────────────────────────────────────────────────

  static String _buildCsv(List<String> headers, List<List<String>> rows) {
    final sb = StringBuffer();
    sb.writeln(headers.join(','));
    for (final row in rows) {
      sb.writeln(row.map(_quote).join(','));
    }
    return sb.toString();
  }

  static String _quote(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _d(String? iso) =>
      iso != null && iso.length >= 10 ? iso.substring(0, 10) : (iso ?? '');

  static String _rentCsv(HomiesState s) => _buildCsv(
        ['Period', 'Housemate', 'Amount (AUD)', 'Paid On', 'Confirmed By'],
        (List.of(s.rentPayments)
              ..sort((a, b) => a.periodStart.compareTo(b.periodStart)))
            .map<List<String>>((p) => [
                  p.periodStart,
                  p.userName,
                  p.amount.toStringAsFixed(2),
                  _d(p.paidAt),
                  p.confirmedBy ?? '',
                ])
            .toList(),
      );

  static String _billsCsv(HomiesState s) => _buildCsv(
        ['Title', 'Category', 'Due Date', 'Total (AUD)', 'Status', 'Housemate', 'Share (AUD)', 'Paid'],
        [
          for (final b in s.bills)
            for (final uid in b.shares.keys)
              [
                b.title,
                b.category,
                b.dueDate,
                b.amount.toStringAsFixed(2),
                b.status,
                s.findUser(uid)?.name ?? uid,
                (b.shares[uid] ?? 0).toStringAsFixed(2),
                (b.paidBy[uid] == true).toString(),
              ],
        ],
      );

  static String _subsCsv(HomiesState s) => _buildCsv(
        ['Name', 'Amount (AUD)', 'Cadence', 'Payer', 'Housemate', 'Share (AUD)', 'Paid'],
        [
          for (final sub in s.subscriptions)
            for (final uid in sub.participants)
              [
                sub.name,
                sub.amount.toStringAsFixed(2),
                sub.cadence,
                s.findUser(sub.payer)?.name ?? sub.payer,
                s.findUser(uid)?.name ?? uid,
                (sub.shares[uid] ?? 0).toStringAsFixed(2),
                (uid == sub.payer || sub.paidBy[uid] == true).toString(),
              ],
        ],
      );

  static String _cleaningCsv(HomiesState s) => _buildCsv(
        ['Task', 'Assignee', 'Due Date', 'Done', 'Completed At', 'Excuse'],
        s.cleaningTasks
            .map((t) => [
                  t.task,
                  s.findUser(t.assignee)?.name ?? t.assignee,
                  t.dueDate,
                  t.done.toString(),
                  t.completedAt ?? '',
                  t.excuse ?? '',
                ])
            .toList(),
      );

  // ── PDF builders ──────────────────────────────────────────────────────────

  static pw.TextStyle get _h2Style =>
      pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _dimStyle =>
      pw.TextStyle(fontSize: 9, color: PdfColors.grey600);

  static pw.Widget _pdfTable(List<String> headers, List<List<String>> rows) {
    if (rows.isEmpty) {
      return pw.Text('No records.', style: _dimStyle);
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 18,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  static List<pw.Widget> _pageHeader(String title, String subtitle) => [
        pw.Text('Homies — $title',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(subtitle, style: _dimStyle),
        pw.Divider(height: 12),
      ];

  static pw.Document _singlePageDoc(
      String title, String subtitle, List<pw.Widget> body) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [..._pageHeader(title, subtitle), ...body],
    ));
    return doc;
  }

  static pw.Document _rentPdf(HomiesState s) {
    final sorted = List.from(s.rentPayments)
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
    return _singlePageDoc(
      'Rent History',
      'All recorded rent payments',
      [
        pw.Text('Rent Payments', style: _h2Style),
        pw.SizedBox(height: 6),
        _pdfTable(
          ['Period', 'Housemate', 'Amount', 'Paid On', 'Confirmed By'],
          sorted
              .map<List<String>>((p) => [
                    p.periodStart,
                    p.userName,
                    '\$${p.amount.toStringAsFixed(2)}',
                    _d(p.paidAt),
                    p.confirmedBy ?? '—',
                  ])
              .toList(),
        ),
      ],
    );
  }

  static pw.Document _billsPdf(HomiesState s) {
    final rows = <List<String>>[];
    for (final b in s.bills) {
      for (final uid in b.shares.keys) {
        rows.add([
          b.title,
          b.dueDate,
          '\$${b.amount.toStringAsFixed(2)}',
          b.status,
          s.findUser(uid)?.name ?? uid,
          '\$${(b.shares[uid] ?? 0).toStringAsFixed(2)}',
          b.paidBy[uid] == true ? 'Yes' : 'No',
        ]);
      }
    }
    return _singlePageDoc(
      'Bills',
      'All bills with per-person breakdown',
      [
        pw.Text('Bills', style: _h2Style),
        pw.SizedBox(height: 6),
        _pdfTable(
          ['Title', 'Due', 'Total', 'Status', 'Housemate', 'Share', 'Paid'],
          rows,
        ),
      ],
    );
  }

  static pw.Document _subsPdf(HomiesState s) {
    final rows = <List<String>>[];
    for (final sub in s.subscriptions) {
      for (final uid in sub.participants) {
        rows.add([
          sub.name,
          '\$${sub.amount.toStringAsFixed(2)}',
          sub.cadence,
          s.findUser(uid)?.name ?? uid,
          '\$${(sub.shares[uid] ?? 0).toStringAsFixed(2)}',
          (uid == sub.payer || sub.paidBy[uid] == true) ? 'Yes' : 'No',
        ]);
      }
    }
    return _singlePageDoc(
      'Subscriptions',
      'Shared subscriptions and splits',
      [
        pw.Text('Subscriptions', style: _h2Style),
        pw.SizedBox(height: 6),
        _pdfTable(
          ['Name', 'Amount', 'Cadence', 'Housemate', 'Share', 'Paid'],
          rows,
        ),
      ],
    );
  }

  static pw.Document _cleaningPdf(HomiesState s) => _singlePageDoc(
        'Cleaning Tasks',
        'Task roster with completion status',
        [
          pw.Text('Cleaning Tasks', style: _h2Style),
          pw.SizedBox(height: 6),
          _pdfTable(
            ['Task', 'Assignee', 'Due Date', 'Status'],
            s.cleaningTasks
                .map<List<String>>((t) => [
                      t.task,
                      s.findUser(t.assignee)?.name ?? t.assignee,
                      t.dueDate,
                      t.done
                          ? 'Done'
                          : (t.excuse?.isNotEmpty == true ? 'Excused' : 'Pending'),
                    ])
                .toList(),
          ),
        ],
      );

  static pw.Document _fullPdf(HomiesState s) {
    final rentSorted = List.from(s.rentPayments)
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));

    final billRows = <List<String>>[];
    for (final b in s.bills) {
      billRows.add([b.title, b.dueDate, '\$${b.amount.toStringAsFixed(2)}', b.status]);
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        ..._pageHeader(
          'Full House Report',
          '${s.property.address} · Exported ${_d(DateTime.now().toIso8601String())}',
        ),
        pw.Text('Rent History', style: _h2Style),
        pw.SizedBox(height: 6),
        _pdfTable(
          ['Period', 'Housemate', 'Amount', 'Paid On'],
          rentSorted
              .map<List<String>>((p) => [
                    p.periodStart,
                    p.userName,
                    '\$${p.amount.toStringAsFixed(2)}',
                    _d(p.paidAt),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 14),
        pw.Text('Bills', style: _h2Style),
        pw.SizedBox(height: 6),
        _pdfTable(['Title', 'Due Date', 'Total', 'Status'], billRows),
        pw.SizedBox(height: 14),
        pw.Text('Cleaning Tasks', style: _h2Style),
        pw.SizedBox(height: 6),
        _pdfTable(
          ['Task', 'Assignee', 'Due Date', 'Status'],
          s.cleaningTasks
              .map<List<String>>((t) => [
                    t.task,
                    s.findUser(t.assignee)?.name ?? t.assignee,
                    t.dueDate,
                    t.done ? 'Done' : 'Pending',
                  ])
              .toList(),
        ),
      ],
    ));
    return doc;
  }

  // ── Share helpers ─────────────────────────────────────────────────────────

  static Future<void> _shareCsv(
      BuildContext context, String name, String csv) async {
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/homies_${name}_$ts.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  static Future<void> _sharePdf(
      BuildContext context, String name, pw.Document doc) async {
    try {
      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'homies_$name.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

// ── Export card widget ────────────────────────────────────────────────────────

class _ExportCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onCsv;
  final VoidCallback? onPdf;

  const _ExportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onCsv,
    this.onPdf,
  });

  @override
  State<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends State<_ExportCard> {
  bool _loading = false;

  Future<void> _run(VoidCallback? fn) async {
    if (fn == null || _loading) return;
    setState(() => _loading = true);
    try {
      fn();
      // Give async ops a moment to complete before clearing loading state
      await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HomiesColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, size: 20, color: HomiesColors.accentStrong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(widget.subtitle,
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          if (widget.onCsv != null)
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _run(widget.onCsv),
              icon: const Icon(Icons.table_chart_outlined, size: 14),
              label: const Text('CSV'),
            ),
          if (widget.onPdf != null)
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _run(widget.onPdf),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('PDF'),
            ),
        ]),
      ]),
    );
  }
}
