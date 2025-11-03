// import 'package:flutter/material.dart';
// import 'package:fyp_hbs/authentication/login.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:fyp_hbs/theme/app_colors.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Geolocator.checkPermission();
//   runApp(const MainApp());
// }

// class MainApp extends StatelessWidget {
//   const MainApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: "Hosba Durian System",
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: AppColors.pakistanGreen,
//           primary: AppColors.pakistanGreen,
//         ),
//         scaffoldBackgroundColor: AppColors.background,
//         appBarTheme: AppBarTheme(
//           backgroundColor: AppColors.pakistanGreen,
//           foregroundColor: Colors.white,
//         ),
//         elevatedButtonTheme: ElevatedButtonThemeData(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: AppColors.pakistanGreen,
//             foregroundColor: Colors.white,
//           ),
//         ),
//         outlinedButtonTheme: OutlinedButtonThemeData(
//           style: OutlinedButton.styleFrom(
//             foregroundColor: AppColors.pakistanGreen,
//             side: BorderSide(color: AppColors.pakistanGreen),
//           ),
//         ),
//         switchTheme: SwitchThemeData(
//           thumbColor: MaterialStateProperty.all(AppColors.pakistanGreen),
//           trackColor: MaterialStateProperty.all(
//             AppColors.pakistanGreen.withOpacity(0.5),
//           ),
//         ),
//         inputDecorationTheme: const InputDecorationTheme(
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(),
//         ),
//       ),
//       home: LoginPage(),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'repositories/tree_repository.dart';
import 'models/tree_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/sync_services.dart';
import 'services/local_db.dart';
import 'utils/connectivity_helper.dart';
import 'package:fyp_hbs/tree/create_tree.dart';

final SyncService _syncService = SyncService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final online = await ConnectivityHelper.hasInternetConnection();

  List<TreeModel> trees = [];

  if (!online) {
    print('📴 Offline mode detected. Loading trees from local DB...');
    final localDB = LocalDB.instance;
    trees = await localDB.fetchAllTrees();
  } else {
    print('🌐 Online mode detected. Fetching trees from remote...');
    final repo = TreeRepository();
    try {
      trees = await repo.getTrees();
    } catch (e) {
      print('⚠️ Failed to fetch from remote. Loading local instead...');
      final localDB = LocalDB.instance;
      trees = await localDB.fetchAllTrees();
    }
  }
  runApp(MyApp(trees: trees));
}

class MyApp extends StatefulWidget {
  final List<TreeModel> trees;
  const MyApp({super.key, required this.trees});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initConnectivityListener();
  }

  void initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((status) async {
      final online = await ConnectivityHelper.hasInternetConnection();
      if (online) {
        print('🌐 Reconnected — syncing data...');
        await _syncService.syncUnsyncedTrees();
      } else {
        print('📴 Offline mode — sync paused');
      }
    });
  }

 @override
Widget build(BuildContext context) {
  return MaterialApp(
    home: TreeHomePage(initialTrees: widget.trees),
  );
}

}

class TreeHomePage extends StatefulWidget {
  final List<TreeModel> initialTrees;
  const TreeHomePage({super.key, required this.initialTrees});

  @override
  State<TreeHomePage> createState() => _TreeHomePageState();
}

class _TreeHomePageState extends State<TreeHomePage> {
  List<TreeModel> trees = [];

  @override
  void initState() {
    super.initState();
    trees = widget.initialTrees;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🌳 Offline Sync Test')),
      body: ListView.builder(
        itemCount: trees.length,
        itemBuilder: (context, index) {
          final tree = trees[index];
          return ListTile(title: Text(tree.treeTag ?? 'Unnamed Tree'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTreePage()),
          );

          if (result == true) {
            final localDB = LocalDB.instance;
            final updatedTrees = await localDB.fetchAllTrees();
            setState(() => trees = updatedTrees);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

