import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const databaseURL = 'https://odoo.your-instance.com';
const databaseName = 'odoo';
const login = 'admin';
const password = 'admin';

// key name must be unique per user/db pair.
const cacheSessionKey = 'odoo-session';

typedef SessionChangedCallback = void Function(OdooSession sessionId);

/// Callback for session changed events
SessionChangedCallback storeSesion(SharedPreferences prefs) {
  /// Define func that will be called on every session update.
  /// It receives configured [SharedPreferences] instance.
  void sessionChanged(OdooSession sessionId) {
    if (sessionId.id == '') {
      prefs.remove(cacheSessionKey);
    } else {
      prefs.setString(cacheSessionKey, json.encode(sessionId.toJson()));
    }
  }

  return sessionChanged;
}

void main() async {
  final logger = Logger();

  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Restore session if it was stored in shared prefs
  final sessionString = prefs.getString(cacheSessionKey);
  OdooSession? session = sessionString == null
      ? null
      : OdooSession.fromJson(json.decode(sessionString));
  final orpc = OdooClient(databaseURL, session);

  // Bind session change listener to store recent session
  final sessionChangedHandler = storeSesion(prefs);
  orpc.sessionStream.listen(sessionChangedHandler);

  /// Here restored session may already be expired.
  /// We will know it on any RPC call getting [OdooSessionExpiredException] exception.
  if (sessionString == null) {
    logger.i('Logging with credentials');
    await orpc.authenticate(databaseName, login, password);
  } else {
    logger.i('Using existing session. Hope it is not expired');
  }

  /// Create provider to pass [orpc] instace to widgets
  runApp(FutureProvider<OdooClient>(
    initialData: orpc,
    create: (context) => Future.value(orpc),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Odoo RPC Demo',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  Future<dynamic> fetchContacts(BuildContext context) {
    /// Get [orpc] instance
    return context.read<OdooClient>().callKw({
      'model': 'res.partner',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'context': {'bin_size': true},
        'domain': [],
        'fields': ['id', 'name', 'email', '__last_update', 'image_128'],
        'limit': 80,
      },
    });
  }

  Widget buildListItem(BuildContext context, Map<String, dynamic> record) {
    var unique = record['__last_update'] as String;
    unique = unique.replaceAll(RegExp(r'[^0-9]'), '');
    final avatarUrl =
        '${context.read<OdooClient>().baseURL}/web/image?model=res.partner'
        '&field=image_128&id=${record["id"]}&unique=$unique';
    return ListTile(
      leading: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
      title: Text(record['name']),
      subtitle: Text(record['email'] is String ? record['email'] : ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: Center(
        child: FutureBuilder(
            future: fetchContacts(context),
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(
                    itemCount: snapshot.data.length,
                    itemBuilder: (context, index) {
                      final record =
                          snapshot.data[index] as Map<String, dynamic>;
                      return buildListItem(context, record);
                    });
              } else {
                if (snapshot.hasError) {
                  return const Text('Unable to fetch data');
                }
                return const CircularProgressIndicator();
              }
            }),
      ),
    );
  }
}
