# Odoo RPC Flutter demo

Very basic demo of [odoo_rpc](https://pub.dev/packages/odoo_rpc) for Flutter.

It uses [Shares Preferences](https://pub.dev/packages/shared_preferences) to store session after login so you don't have to login on every app start.

[Provider](https://pub.dev/packages/provider) is used to pass `OdooClient` instance across widget tree.

[FutureBuilder](https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html) is used to show spinner while RPC call is being executed.

Real app should handle session expired exception to resert login state and redirect user to login screen.
