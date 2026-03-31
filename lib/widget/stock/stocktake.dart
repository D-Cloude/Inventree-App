import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/stock.dart";
import "package:inventree/helpers.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Represents a single entry in the stocktake list.
 */
class _StocktakeEntry {
  _StocktakeEntry({
    required this.item,
    required this.countedQuantity,
  });

  final InvenTreeStockItem item;
  double countedQuantity;
}

/*
 * Widget for performing a batch stocktake (재물조사) on a stock location.
 *
 * Allows the user to scan multiple stock items and set their counted quantities,
 * then submit all counts at once to the server via stock/count/.
 */
class StocktakeWidget extends StatefulWidget {
  const StocktakeWidget({Key? key}) : super(key: key);

  @override
  _StocktakeState createState() => _StocktakeState();
}

class _StocktakeState extends State<StocktakeWidget> {
  final List<_StocktakeEntry> _entries = [];
  bool _submitting = false;

  // Add or update a stock item in the list
  void _addItem(InvenTreeStockItem item) {
    setState(() {
      // If already in list, just highlight it
      for (var entry in _entries) {
        if (entry.item.pk == item.pk) {
          showSnackIcon(
            "${item.partName} (${item.displayQuantity})",
            success: true,
          );
          return;
        }
      }
      _entries.add(
        _StocktakeEntry(item: item, countedQuantity: item.quantity),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _entries.removeAt(index);
    });
  }

  Future<void> _scanItem() async {
    await scanBarcode(
      context,
      handler: StocktakeScanItemHandler(_addItem),
    );
  }

  Future<void> _submitStocktake() async {
    if (_entries.isEmpty) {
      showSnackIcon(L10().stocktakeNoItems, success: false);
      return;
    }

    setState(() => _submitting = true);

    final List<Map<String, dynamic>> items = _entries
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

    setState(() => _submitting = false);

    if (response.isValid() &&
        (response.statusCode == 200 || response.statusCode == 201)) {
      showSnackIcon(L10().stocktakeSuccess, success: true);
      setState(() => _entries.clear());
    } else {
      showSnackIcon(L10().requestFailed, success: false);
    }
  }

  Widget _buildEntryRow(_StocktakeEntry entry, int index) {
    return Card(
      key: ValueKey(entry.item.pk),
      child: ListTile(
        leading: InvenTreeAPI().getThumbnail(entry.item.partImage),
        title: Text(entry.item.partName),
        subtitle: Text(
          entry.item.batch.isNotEmpty
              ? "${L10().stockLocation}: ${entry.item.locationPathString}  |  ${L10().batchCode}: ${entry.item.batch}"
              : "${L10().stockLocation}: ${entry.item.locationPathString}",
          style: TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: simpleNumberString(entry.countedQuantity),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed >= 0) {
                    entry.countedQuantity = parsed;
                  }
                },
              ),
            ),
            IconButton(
              icon: Icon(TablerIcons.trash, color: COLOR_DANGER),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10().stocktake),
        actions: [
          if (_entries.isNotEmpty)
            TextButton(
              onPressed: _submitting ? null : _submitStocktake,
              child: Text(
                L10().stocktakeSubmit,
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(TablerIcons.clipboard_check, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    L10().stocktakeNoItems,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(TablerIcons.qrcode),
                    label: Text(L10().stocktakeScanItem),
                    onPressed: _scanItem,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (ctx, i) =>
                        _buildEntryRow(_entries[i], i),
                  ),
                ),
                if (_submitting)
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(TablerIcons.qrcode),
        label: Text(L10().stocktakeScanItem),
        onPressed: _scanItem,
      ),
    );
  }
}
