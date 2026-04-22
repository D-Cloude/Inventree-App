import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:open_filex/open_filex.dart";
import "package:path_provider/path_provider.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/stock.dart";
import "package:inventree/barcode/tones.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/inventree/sentry.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Represents a single entry in the stocktake list.
 */
class _StocktakeEntry {
  _StocktakeEntry({
    required this.item,
    required this.countedQuantity,
    this.isScanned = false,
  });

  final InvenTreeStockItem item;
  double countedQuantity;
  bool isScanned; // true if confirmed by barcode scan
}

/*
 * Widget for performing a batch stocktake (재물조사) on a stock location.
 *
 * When a location is provided, all items in that location are pre-loaded
 * and the widget enters "verification mode": scanning a barcode marks the
 * matching item as confirmed. Items not in the list show an error.
 *
 * Without a location, the widget runs in "free-form" mode where scanning
 * any stock item adds it to the list.
 *
 * On submission, results are automatically exported as a CSV file.
 */
class StocktakeWidget extends StatefulWidget {
  const StocktakeWidget({this.location, Key? key}) : super(key: key);

  final InvenTreeStockLocation? location;

  @override
  _StocktakeState createState() => _StocktakeState();
}

class _StocktakeState extends State<StocktakeWidget> {
  final List<_StocktakeEntry> _entries = [];
  bool _submitting = false;
  bool _loading = false;

  // True when location is pre-loaded: scanning only verifies existing items
  bool get _verificationMode => widget.location != null;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _loadLocationItems();
    }
  }

  Future<void> _loadLocationItems() async {
    try {
      setState(() => _loading = true);

      final items = await InvenTreeStockItem().list(filters: {
        "location": widget.location!.pk.toString(),
        "in_stock": "true",
      });

      if (!mounted) return;

      // Process items in the next frame to avoid UI blocking
      await Future.delayed(Duration(milliseconds: 10));

      if (mounted) {
        setState(() {
          _entries.clear();
          for (var item in items) {
            if (item is InvenTreeStockItem && item.pk != null) {
              _entries.add(
                _StocktakeEntry(item: item, countedQuantity: item.quantity),
              );
            }
          }
          _loading = false;
        });
      }
    } catch (error, stackTrace) {
      sentryReportError("_loadLocationItems", error, stackTrace);
      print("Error loading location items: $error");
      print(stackTrace);

      if (mounted) {
        setState(() => _loading = false);
        showSnackIcon(L10().errorLoadingItems, success: false);
      }
    }
  }

  /*
   * Called when a barcode scan completes.
   *
   * In verification mode: only marks existing items as confirmed.
   * In free-form mode: also adds items not currently in the list.
   */
  void _onItemScanned(InvenTreeStockItem item) {
    try {
      setState(() {
        for (var entry in _entries) {
          if (entry.item.pk == item.pk) {
            entry.isScanned = true;
            showSnackIcon(
              "${item.partName} — ${L10().stocktakeItemVerified}",
              success: true,
            );
            return;
          }
        }

        if (_verificationMode) {
          // Item not in the pre-loaded list → error
          barcodeFailureTone();
          showSnackIcon(L10().stocktakeItemNotFound, success: false);
        } else {
          // Free-form mode: add the new item
          _entries.add(
            _StocktakeEntry(
              item: item,
              countedQuantity: item.quantity,
              isScanned: true,
            ),
          );
          showSnackIcon(
            "${item.partName} — ${L10().stocktakeItemVerified}",
            success: true,
          );
        }
      });
    } catch (error, stackTrace) {
      sentryReportError("_onItemScanned", error, stackTrace);
      print("Error in _onItemScanned: $error");
      print(stackTrace);
      if (mounted) {
        showSnackIcon(L10().errorProcessingItem, success: false);
      }
    }
  }

  void _removeItem(int index) {
    setState(() {
      if (index >= 0 && index < _entries.length) {
        _entries.removeAt(index);
      }
    });
  }

  Future<void> _scanItem() async {
    try {
      await scanBarcode(
        context,
        handler: StocktakeScanItemHandler(_onItemScanned),
      );
    } catch (error, stackTrace) {
      sentryReportError("_scanItem", error, stackTrace);
      print("Error scanning item: $error");
      print(stackTrace);
      if (mounted) {
        showSnackIcon(L10().errorScanningItem, success: false);
      }
    }
  }

  /*
   * Export current stocktake results to a CSV file and open it.
   * The CSV uses UTF-8 BOM so Excel opens it with correct encoding.
   */
  Future<void> _exportResults() async {
    try {
      final StringBuffer csv = StringBuffer();

      // UTF-8 BOM for Excel Korean compatibility
      csv.write("\uFEFF");
      csv.writeln(
        "${L10().stocktakeCsvPartName},"
        "${L10().stocktakeCsvBatch},"
        "${L10().stocktakeCsvLocation},"
        "${L10().stocktakeCsvQuantity},"
        "${L10().stocktakeCsvStatus}",
      );

      for (var entry in _entries) {
        String cell(String s) => '"${s.replaceAll('"', '""')}"';
        final verified =
            entry.isScanned ? L10().stocktakeVerified : L10().stocktakeUnverified;
        csv.writeln(
          "${cell(entry.item.partName)},"
          "${cell(entry.item.batch)},"
          "${cell(entry.item.locationPathString)},"
          "${entry.countedQuantity},"
          "$verified",
        );
      }

      final Directory dir = await getTemporaryDirectory();
      final String ts = DateTime.now()
          .toIso8601String()
          .replaceAll(":", "-")
          .split(".")
          .first;
      final String path = "${dir.path}/stocktake_$ts.csv";

      final File file = File(path);
      await file.writeAsString(csv.toString(), encoding: utf8);

      await OpenFilex.open(path);

      showSnackIcon(L10().stocktakeExported, success: true);
    } catch (error, stackTrace) {
      sentryReportError("_exportResults", error, stackTrace);
      print("Error exporting results: $error");
      print(stackTrace);
      if (mounted) {
        showSnackIcon(L10().errorExportingResults, success: false);
      }
    }
  }

  Future<void> _submitStocktake() async {
    if (_entries.isEmpty) {
      showSnackIcon(L10().stocktakeNoItems, success: false);
      return;
    }

    setState(() => _submitting = true);

    try {
      final List<Map<String, dynamic>> items = _entries
          .where((e) => e.item.pk != null)
          .map(
            (e) => {
              "pk": "${e.item.pk}",
              "quantity": "${e.countedQuantity}",
            },
          )
          .toList();

      final response = await InvenTreeAPI().post(
        "stock/count/",
        body: {"items": items, "notes": ""},
        expectedStatusCode: null,
      );

      if (response.isValid() &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        showSnackIcon(L10().stocktakeSuccess, success: true);
        await _exportResults();
        if (mounted) {
          setState(() => _entries.clear());
        }
      } else {
        showSnackIcon(L10().requestFailed, success: false);
      }
    } catch (error, stackTrace) {
      sentryReportError("_submitStocktake", error, stackTrace);
      print("Error submitting stocktake: $error");
      print(stackTrace);
      if (mounted) {
        showSnackIcon(L10().stocktakeSubmitError, success: false);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildEntryRow(_StocktakeEntry entry, int index) {
    return Card(
      key: ValueKey(entry.item.pk),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InvenTreeAPI().getThumbnail(entry.item.partImage) ??
                  const Icon(TablerIcons.package, size: 40, color: Colors.grey),
              if (entry.isScanned)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      TablerIcons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          entry.item.partName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          entry.item.batch.isNotEmpty
              ? "${L10().batchCode}: ${entry.item.batch}\n${entry.item.locationPathString}"
              : entry.item.locationPathString,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 70,
              child: TextFormField(
                initialValue: simpleNumberString(entry.countedQuantity),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  // If input is not a positive number, default to 0 as per request
                  if (parsed != null && parsed >= 0) {
                    entry.countedQuantity = parsed;
                  } else {
                    entry.countedQuantity = 0;
                  }
                },
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(TablerIcons.trash, color: COLOR_DANGER, size: 20),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = L10().stocktake;
    if (widget.location != null) {
      title += " — ${widget.location!.name}";
    }

    final int scannedCount = _entries.where((e) => e.isScanned).length;
    final int totalCount = _entries.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Progress counter: scanned / total
          if (totalCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "$scannedCount/$totalCount",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (totalCount > 0)
            TextButton(
              onPressed: _exportResults,
              child: Text(
                L10().save,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Verification mode banner
          if (_verificationMode)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    TablerIcons.scan,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    L10().stocktakeVerificationMode,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (totalCount > 0) ...[
                    const Spacer(),
                    // Progress bar chip
                    Text(
                      "$scannedCount / $totalCount ${L10().stocktakeVerified}",
                      style: TextStyle(
                        color: scannedCount == totalCount
                            ? Colors.green
                            : Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Main content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              TablerIcons.clipboard_check,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              L10().stocktakeNoItems,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(TablerIcons.qrcode),
                              label: Text(L10().stocktakeScanItem),
                              onPressed: _scanItem,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (ctx, i) =>
                            _buildEntryRow(_entries[i], i),
                      ),
          ),

          if (_submitting)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(TablerIcons.qrcode),
        label: Text(L10().stocktakeScanItem),
        onPressed: _scanItem,
      ),
    );
  }
}
