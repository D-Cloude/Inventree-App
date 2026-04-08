import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";

import "package:inventree/api.dart";
import "package:inventree/app_colors.dart";
import "package:inventree/inventree/stock.dart";
import "package:inventree/l10.dart";
import "package:inventree/widget/stock/location_display.dart";
import "package:inventree/widget/stock/stocktake.dart";
import "package:inventree/widget/stock/location_transfer.dart";
import "package:inventree/widget/snacks.dart";

/*
 * Features page - additional functionality beyond main navigation
 */
class FeaturesWidget extends StatefulWidget {
  const FeaturesWidget({Key? key}) : super(key: key);

  @override
  _FeaturesWidgetState createState() => _FeaturesWidgetState();
}

class _FeaturesWidgetState extends State<FeaturesWidget> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /*
   * Show location selection dialog for stocktake
   */
  Future<void> _selectLocationForStocktake() async {
    final locations = await InvenTreeStockLocation().list();

    if (locations.isEmpty) {
      showSnackIcon(L10().noLocationsFound, success: false);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${L10().stocktake} - ${L10().selectLocation}"),
        content: Container(
          constraints: BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            itemCount: locations.length,
            itemBuilder: (ctx, i) {
              final loc = locations[i];
              if (loc is InvenTreeStockLocation) {
                return ListTile(
                  title: Text(loc.name),
                  subtitle: loc.description.isNotEmpty
                      ? Text(loc.description)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StocktakeWidget(location: loc),
                      ),
                    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(L10().features),
        backgroundColor: COLOR_APP_BAR,
      ),
      body: Center(
        child: ListView(
          padding: EdgeInsets.all(8),
          children: [
            // Stocktake Section
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                L10().stocktake,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: Text(L10().stocktake),
                subtitle: Text(L10().stocktakeDescription),
                leading: Icon(TablerIcons.clipboard_check, color: COLOR_ACTION),
                trailing: Icon(TablerIcons.chevron_right),
                onTap: _selectLocationForStocktake,
              ),
            ),

            // Location Transfer
            Card(
              child: ListTile(
                title: Text(L10().locationTransfer),
                subtitle: Text(L10().locationTransferDescription),
                leading: Icon(TablerIcons.transfer, color: COLOR_ACTION),
                trailing: Icon(TablerIcons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LocationTransferWidget()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
