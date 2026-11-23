import 'package:flutter/material.dart';
import 'core/app_mode.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BlovyPosApp());
}

class BlovyPosApp extends StatefulWidget {
  const BlovyPosApp({super.key});

  @override
  State<BlovyPosApp> createState() => _BlovyPosAppState();
}

class _BlovyPosAppState extends State<BlovyPosApp> {
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
      title: 'BLOVY POS',
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
        mode: AppTargetMode.posOnly,
        tema: _tema,
        onGantiTema: _gantiTema,
      ),
    );
  }
}
