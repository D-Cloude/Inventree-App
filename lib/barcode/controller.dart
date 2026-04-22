import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "package:inventree/helpers.dart";
import "package:inventree/preferences.dart";
import "package:inventree/barcode/handler.dart";
import "package:inventree/widget/progress.dart";

/*
 * Generic class which provides a barcode scanner interface.
 * 
 * When the controller is instantiated, it is passed a "handler" class,
 * which is used to process the scanned barcode.
 */
class InvenTreeBarcodeController extends StatefulWidget {
  const InvenTreeBarcodeController(this.handler, {Key? key}) : super(key: key);

  final BarcodeHandler handler;

  @override
  State<StatefulWidget> createState() => InvenTreeBarcodeControllerState();
}

/*
 * Base state widget for the barcode controller.
 * This defines the basic interface for the barcode controller.
 */
class InvenTreeBarcodeControllerState
    extends State<InvenTreeBarcodeController> {
  InvenTreeBarcodeControllerState() : super();

  final GlobalKey barcodeControllerKey = GlobalKey(
    debugLabel: "barcodeController",
  );

  // Internal state flag to test if we are currently processing a barcode
  bool processingBarcode = false;

  // Buffer for external barcode scanner (keyboard wedge)
  final StringBuffer scannedCharactersBuffer = StringBuffer();
  DateTime? lastScanTime;

  /*
   * Method to handle key events from an external barcode scanner
   */
  void handleKeyEvent(KeyEvent event) {
    if (processingBarcode || !mounted) {
      return;
    }

    // Look only for key-down events
    if (event is! KeyDownEvent) {
      return;
    }

    // Ignore events without a character code
    if (event.character == null) {
      return;
    }

    DateTime now = DateTime.now();

    // Clear buffer if the time between keypresses is too long (not a scanner)
    if (lastScanTime == null ||
        lastScanTime!.isBefore(now.subtract(Duration(milliseconds: 100)))) {
      scannedCharactersBuffer.clear();
    }

    lastScanTime = now;

    if (event.character == "\n" || event.logicalKey == LogicalKeyboardKey.enter) {
      if (scannedCharactersBuffer.isNotEmpty) {
        final String data = scannedCharactersBuffer.toString();
        debug("External scanner: $data");
        handleBarcodeData(data);
      }

      scannedCharactersBuffer.clear();
    } else {
      scannedCharactersBuffer.write(event.character!);
    }
  }

  /*
   * Method to handle scanned data.
...
   * Barcode data should be passed as a string
   */
  Future<void> handleBarcodeData(String? data) async {
    // Check that the data is valid, and this view is still mounted
    if (!mounted || data == null || data.isEmpty) {
      return;
    }

    // Currently processing a barcode - ignore this one
    if (processingBarcode) {
      return;
    }

    setState(() {
      processingBarcode = true;
    });

    showLoadingOverlay();
    await pauseScan();

    await widget.handler.processBarcode(data);

    // processBarcode may have popped the context
    if (!mounted) {
      hideLoadingOverlay();
      return;
    }

    int delay =
        await InvenTreeSettingsManager().getValue(INV_BARCODE_SCAN_DELAY, 500)
            as int;

    Future.delayed(Duration(milliseconds: delay), () {
      hideLoadingOverlay();
      if (mounted) {
        resumeScan().then((_) {
          if (mounted) {
            setState(() {
              processingBarcode = false;
            });
          }
        });
      }
    });
  }

  // Hook function to "pause" the barcode scanner
  Future<void> pauseScan() async {
    // Implement this function in subclass
  }

  // Hook function to "resume" the barcode scanner
  Future<void> resumeScan() async {
    // Implement this function in subclass
  }

  /*
   * Implementing classes are in control of building out the widget
   */
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
