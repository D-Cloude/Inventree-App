import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/app_colors.dart";
import "package:inventree/barcode/barcode.dart";
import "package:inventree/barcode/controller.dart";
import "package:inventree/barcode/handler.dart";

import "package:inventree/l10.dart";
import "package:inventree/helpers.dart";
import "package:inventree/preferences.dart";

/*
 * Barcode controller which acts as a keyboard wedge,
 * intercepting barcode data which is entered as rapid keyboard presses
 */
class WedgeBarcodeController extends InvenTreeBarcodeController {
  const WedgeBarcodeController(BarcodeHandler handler, {Key? key})
    : super(handler, key: key);

  @override
  State<StatefulWidget> createState() => _WedgeBarcodeControllerState();
}

class _WedgeBarcodeControllerState extends InvenTreeBarcodeControllerState {
  _WedgeBarcodeControllerState() : super();

  bool canScan = true;

  bool get scanning => mounted && canScan;

  final FocusNode _focusNode = FocusNode();

  @override
  Future<void> pauseScan() async {
    if (mounted) {
      setState(() {
        canScan = false;
      });
    }
  }

  @override
  Future<void> resumeScan() async {
    if (mounted) {
      setState(() {
        canScan = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: COLOR_APP_BAR,
        title: Text(L10().scanBarcode),
      ),
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      floatingActionButton: FloatingActionButton(
        child: const Icon(TablerIcons.camera),
        tooltip: L10().barcodeScanGeneral,
        onPressed: () async {
          // Switch to camera mode
          await InvenTreeSettingsManager().setValue(INV_BARCODE_SCAN_TYPE, BARCODE_CONTROLLER_CAMERA);
          if (mounted) {
            Navigator.pop(context);
            scanBarcode(context, handler: widget.handler);
          }
        },
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(flex: 5),
            Icon(TablerIcons.barcode, size: 64),
            Spacer(flex: 5),
            KeyboardListener(
              autofocus: true,
              focusNode: _focusNode,
              child: SizedBox(
                child: CircularProgressIndicator(
                  color: scanning ? COLOR_ACTION : COLOR_PROGRESS,
                ),
                width: 64,
                height: 64,
              ),
              onKeyEvent: (event) {
                if (scanning) {
                  handleKeyEvent(event);
                }
              },
            ),
            Spacer(flex: 5),
            Padding(
              child: Text(
                widget.handler.getOverlayText(context),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              padding: EdgeInsets.all(20),
            ),
          ],
        ),
      ),
    );
  }
}
