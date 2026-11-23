import 'package:flutter/material.dart';
import 'core/app_mode.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BlovySisApp());
}

class BlovySisApp extends StatefulWidget {
  const BlovySisApp({super.key});

  @override
  State<BlovySisApp> createState() => _BlovySisAppState();
}

class _BlovySisAppState extends State<BlovySisApp> {
  final StorageService _storage = StorageService();
  AppThemeConfig _tema = kDaftarTema.first;

  @override
  void initState() {
    super.initState();
    _muatTema();
  }

  Future<void> _muatTema() async {
    final id = await _storage.muatTemaId();
    if (!mounted) return;
    setState(() {
      _tema = cariTemaById(id);
    });
  }

  void _gantiTema(String id) {
    setState(() {
      _tema = cariTemaById(id);
    });
    _storage.simpanTemaId(id);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _tema.isDark ? Brightness.dark : Brightness.light;
    return MaterialApp(
      title: 'BLOVY SIS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: _tema.bgColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _tema.primaryColor,
          brightness: brightness,
          primary: _tema.primaryColor,
          secondary: _tema.accentColor,
          surface: _tema.surfaceColor,
        ),
        dividerTheme: DividerThemeData(
          color: _tema.borderColor,
          thickness: 1,
        ),
      ),
      home: PosMainShell(
        mode: AppTargetMode.sisOnly,
        tema: _tema,
        onGantiTema: _gantiTema,
      ),
    );
  }
}
