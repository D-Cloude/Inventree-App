import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/snacks.dart";
import "package:inventree/widget/spinner.dart";
import "package:inventree/barcode/tones.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/handler.dart";
import "package:inventree/preferences.dart";
import "package:one_context/one_context.dart";
import "package:inventree/api_form.dart";

/*
 * Location Transfer Widget - Transfer stock items between locations
 */
class LocationTransferWidget extends StatefulWidget {
  final InvenTreeStockLocation? sourceLocation;
  final InvenTreeStockLocation? targetLocation;

  const LocationTransferWidget({
    Key? key,
    this.sourceLocation,
    this.targetLocation,
  }) : super(key: key);

  @override
  _LocationTransferWidgetState createState() => _LocationTransferWidgetState();
}

class _LocationTransferWidgetState extends State<LocationTransferWidget> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Selected locations
  InvenTreeStockLocation? _sourceLocation;
  InvenTreeStockLocation? _targetLocation;

  // Transfer mode: 0 = scan mode, 1 = list mode
  int _transferMode = 0;

  // Selected items for bulk transfer (list mode)
  final List<int> _selectedItemIds = [];

  // Loading state
  bool _isLoading = false;
  bool _isTransferring = false;

  // Items list for list mode
  List<InvenTreeStockItem> _items = [];

  @override
  void initState() {
    super.initState();
    _sourceLocation = widget.sourceLocation;
    _targetLocation = widget.targetLocation;
  }

  /*
   * Show location selection dialog
   */
  Future<void> _selectLocation({bool isTarget = false}) async {
    final locations = await InvenTreeStockLocation().list();

    if (locations.isEmpty) {
      showSnackIcon(L10().noLocationsFound, success: false);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTarget ? L10().selectTargetLocation : L10().selectSourceLocation),
        content: Container(
          constraints: BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            itemCount: locations.length,
            itemBuilder: (ctx, i) {
              final loc = locations[i];
              if (loc is InvenTreeStockLocation) {
                final isSelected = isTarget
                    ? _targetLocation?.pk == loc.pk
                    : _sourceLocation?.pk == loc.pk;

                return ListTile(
                  title: Text(loc.name),
                  subtitle: loc.description.isNotEmpty
                      ? Text(loc.description)
                      : null,
                  leading: Icon(
                    isSelected ? TablerIcons.check : TablerIcons.home,
                    color: isSelected ? COLOR_ACTION : Colors.grey,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      if (isTarget) {
                        _targetLocation = loc;
                      } else {
                        _sourceLocation = loc;
                      }
                    });
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  /*
   * Load items from source location for list mode
   */
  Future<void> _loadItems() async {
    if (_sourceLocation == null) {
      showSnackIcon(L10().selectSourceLocation, success: false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final items = await InvenTreeStockItem().list(
        filters: {"location": _sourceLocation!.pk.toString()},
      );

      if (items is List) {
        setState(() {
          _items = items.whereType<InvenTreeStockItem>().toList();
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /*
   * Start transfer process
   */
  void _startTransfer() {
    if (_targetLocation == null) {
      showSnackIcon(L10().selectTargetLocation, success: false);
      return;
    }

    if (_transferMode == 1 && _sourceLocation == null) {
      showSnackIcon(L10().selectSourceLocation, success: false);
      return;
    }

    if (_transferMode == 1) {
      _loadItems();
    } else {
      _startScanner();
    }
  }

  /*
   * Start barcode scanner for scan mode
   */
  void _startScanner() {
    // Create a custom handler for location transfer
    final handler = _LocationTransferBarcodeHandler(_targetLocation!);

    scanBarcode(context, handler: handler);
  }

  /*
   * Handle scanned item
   */
  Future<void> _handleScannedItem(String barcode) async {
    // Try to parse as item ID first
    int? itemId;
    try {
      itemId = int.parse(barcode);
    } catch (e) {
      // Not a valid ID, try to find by barcode
      final items = await InvenTreeStockItem().list(
        filters: {"barcode": barcode},
      );
      if (items is List && items.isNotEmpty) {
        final item = items.whereType<InvenTreeStockItem>().firstOrNull;
        if (item != null && item.pk != null) {
          itemId = item.pk;
        }
      }
    }

    if (itemId == null) {
      showSnackIcon(L10().itemNotFound, success: false);
      return;
    }

    // Transfer the item
    await _transferItem(itemId);
  }

  /*
   * Transfer a single item
   */
  Future<void> _transferItem(int itemId) async {
    final item = await InvenTreeStockItem().get(itemId) as InvenTreeStockItem?;

    if (item == null) {
      showSnackIcon(L10().itemNotFound, success: false);
      return;
    }

    // Check if item is already in target location
    if (item.locationId == _targetLocation!.pk) {
      await barcodeSuccessTone();
      showSnackIcon(L10().itemInLocation, success: true);
      return;
    }

    setState(() {
      _isTransferring = true;
    });

    try {
      final result = await item.transferStock(
        _targetLocation!.pk,
        notes: L10().locationTransferNote,
      );

      if (result) {
        await barcodeSuccessTone();
        showSnackIcon(L10().itemTransferred, success: true);
      } else {
        showSnackIcon(L10().transferFailed, success: false);
      }
    } finally {
      setState(() {
        _isTransferring = false;
      });
    }
  }

  /*
   * Transfer selected items (bulk transfer)
   */
  Future<void> _transferSelectedItems() async {
    if (_selectedItemIds.isEmpty) {
      showSnackIcon(L10().selectItemsToTransfer, success: false);
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10().confirmTransferItems),
        content: Text(
            "${L10().transferItemsMessage}"
                .replaceAll("{count}", _selectedItemIds.length.toString())
                .replaceAll("{location}", _targetLocation!.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10().cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10().confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isTransferring = true;
    });

    int successCount = 0;
    int failCount = 0;

    try {
      for (final itemId in _selectedItemIds) {
        final item = await InvenTreeStockItem().get(itemId) as InvenTreeStockItem?;

        if (item != null && item.locationId != _targetLocation!.pk) {
          final result = await item.transferStock(
            _targetLocation!.pk,
            notes: L10().locationTransferNote,
          );

          if (result) {
            successCount++;
          } else {
            failCount++;
          }
        }
      }

      // Refresh items list
      await _loadItems();

      // Clear selection
      _selectedItemIds.clear();

      if (mounted) {
        if (failCount > 0) {
          showSnackIcon(
              "$successCount ${L10().itemsTransferred}, $failCount ${L10().transferFailed}",
              success: false);
        } else {
          showSnackIcon("$successCount ${L10().itemsTransferred}", success: true);
        }
      }
    } finally {
      setState(() {
        _isTransferring = false;
      });
    }
  }

  /*
   * Toggle item selection
   */
  void _toggleItemSelection(int itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(L10().locationTransfer),
        backgroundColor: COLOR_APP_BAR,
      ),
      body: Container(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Target Location Selector (Required)
            Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      "${L10().targetLocation} *",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    ListTile(
                      title: Text(_targetLocation?.name ?? L10().selectTargetLocation),
                      leading: Icon(TablerIcons.home, color: COLOR_ACTION),
                      trailing: Icon(TablerIcons.chevron_right),
                      onTap: () => _selectLocation(isTarget: true),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Source Location Selector (Optional)
            Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      "$L10().sourceLocation ${L10().optional}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    ListTile(
                      title: Text(_sourceLocation?.name ?? L10().selectSourceLocation),
                      leading: Icon(TablerIcons.home, color: Colors.grey),
                      trailing: Icon(TablerIcons.chevron_right),
                      onTap: () => _selectLocation(isTarget: false),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Transfer Mode Selector
            Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      L10().transferMode,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            title: Text(L10().scanMode),
                            value: 0,
                            groupValue: _transferMode,
                            onChanged: (value) {
                              setState(() {
                                _transferMode = value!;
                                _selectedItemIds.clear();
                                _items.clear();
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            title: Text(L10().listMode),
                            value: 1,
                            groupValue: _transferMode,
                            onChanged: (value) {
                              setState(() {
                                _transferMode = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Start Transfer Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTransferring ? null : _startTransfer,
                icon: _isTransferring
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(TablerIcons.rss),
                label: Text(_transferMode == 0 ? L10().startTransfer : L10().selectItemsToTransfer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: COLOR_ACTION,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Transfer Area - Scan Mode
            if (_transferMode == 0 && _targetLocation != null)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(TablerIcons.qrcode, size: 48, color: COLOR_ACTION),
                      SizedBox(height: 8),
                      Text(
                        L10().scanItemToTransfer,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        L10().targetLocationValue,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        _targetLocation!.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: COLOR_ACTION,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // List Mode Items
            if (_transferMode == 1 && _items.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            L10().items,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (_selectedItemIds.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: _isTransferring ? null : _transferSelectedItems,
                              icon: Icon(TablerIcons.rss),
                              label: Text("${L10().transferSelected} (${_selectedItemIds.length})"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: COLOR_ACTION,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8),
                      if (_isLoading)
                        Center(child: Spinner(icon: null,))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final item = _items[i];
                            final isSelected = _selectedItemIds.contains(item.pk!);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (value) {
                                _toggleItemSelection(item.pk!);
                              },
                              title: Text(item.partName),
                              subtitle: Text("${item.partName} - ${item.quantity} ${item.units}"),
                              secondary: Icon(TablerIcons.package, color: Colors.grey),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/*
 * Barcode handler for location transfer
 */
class _LocationTransferBarcodeHandler extends BarcodeHandler {
  final InvenTreeStockLocation targetLocation;

  _LocationTransferBarcodeHandler(this.targetLocation);

  @override
  String getOverlayText(BuildContext context) => L10().scanItemToTransfer;

  @override
  Future<void> onBarcodeMatched(Map<String, dynamic> data) async {
    // Get the stock item from the response
    int? itemId;

    // Try to get stockitem pk from response
    if (data.containsKey("stockitem")) {
      final stockitemData = data["stockitem"];
      if (stockitemData is Map) {
        itemId = stockitemData["pk"] as int?;
      } else if (stockitemData is int) {
        itemId = stockitemData;
      }
    }

    if (itemId == null) {
      await onBarcodeUnknown(data);
      return;
    }

    // Transfer the item
    final item = await InvenTreeStockItem().get(itemId) as InvenTreeStockItem?;

    if (item == null) {
      await barcodeFailureTone();
      showSnackIcon(L10().itemNotFound, success: false);
      return;
    }

    // Check if item is already in target location
    if (item.locationId == targetLocation.pk) {
      await barcodeSuccessTone();
      showSnackIcon(L10().itemInLocation, success: true);
      return;
    }

    // Check for confirm setting
    final bool confirm = await InvenTreeSettingsManager().getBool(
      INV_STOCK_CONFIRM_SCAN,
      false,
    );

    // Check for auto-transfer setting
    final bool autoTransfer = await InvenTreeSettingsManager().getBool(
      INV_STOCK_AUTO_TRANSFER,
      false,
    );

    // Determine the notes field value
    String notes = autoTransfer ? L10().autoTransferNote : L10().locationTransferNote;

    // If confirm is enabled, launch an ApiForm to confirm the transfer
    if (confirm) {
      // Get the transfer form fields
      final fields = item.transferFields();
      fields["location"]?["value"] = targetLocation.pk;
      fields["notes"] = notes;

      launchApiForm(
        OneContext().context!,
        L10().transferStock,
        InvenTreeStockItem.transferStockUrl(),
        fields,
        method: "POST",
        icon: TablerIcons.transfer,
        onSuccess: (data) {
          showSnackIcon(L10().stockItemUpdated, success: true);
        },
      );
      return;
    }

    // Transfer the item
    final result = await item.transferStock(
      targetLocation.pk,
      notes: notes,
    );

    if (result) {
      await barcodeSuccessTone();
      showSnackIcon(L10().itemTransferred, success: true);
    } else {
      await barcodeFailureTone();
      showSnackIcon(L10().transferFailed, success: false);
    }
  }
}
