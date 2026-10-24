import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:karing/i18n/strings.g.dart';

/// Reconstructed read-only record viewer. The release's private chart sources
/// are absent; existing statistics databases remain readable without migration.
class StatisticsRecordsScreen extends StatefulWidget {
  final String dbPath;
  final bool currentDB;
  const StatisticsRecordsScreen({
    super.key,
    required this.dbPath,
    required this.currentDB,
  });
  static RouteSettings routeSettings() =>
      const RouteSettings(name: 'StatisticsRecordsScreen');
  @override
  State<StatisticsRecordsScreen> createState() =>
      _StatisticsRecordsScreenState();
}

class _StatisticsRecordsScreenState extends State<StatisticsRecordsScreen> {
  List<String> _columns = [];
  List<List<Object?>> _rows = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Database? database;
    try {
      if (!await File(widget.dbPath).exists()) {
        _rows = [];
        _columns = [];
        return;
      }
      database = sqlite3.open(widget.dbPath, mode: OpenMode.readOnly);
      final tables = database.select(
        "SELECT name FROM sqlite_master WHERE type IS 'table' AND name IS 'records'",
      );
      if (tables.isEmpty) {
        _rows = [];
        _columns = [];
        return;
      }
      final result = database.select(
        'SELECT * FROM records ORDER BY rowid DESC LIMIT 500',
      );
      _columns = result.columnNames;
      _rows = result
          .map((row) => _columns.map((column) => row[column]).toList())
          .toList();
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      database?.dispose();
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Translations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr.meta.records),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: SelectableText(_error!))
          : _rows.isEmpty
          ? Center(child: Text(tr.meta.records + ': 0'))
          : Scrollbar(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: _columns
                        .map((name) => DataColumn(label: Text(name)))
                        .toList(),
                    rows: _rows
                        .map(
                          (row) => DataRow(
                            cells: row
                                .map(
                                  (value) => DataCell(
                                    SelectableText(value?.toString() ?? ''),
                                  ),
                                )
                                .toList(),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
    );
  }
}
