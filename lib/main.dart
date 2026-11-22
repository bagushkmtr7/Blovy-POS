import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosRetailProApp());
}

class PosRetailProApp extends StatefulWidget {
  const PosRetailProApp({super.key});

  @override
  State<PosRetailProApp> createState() => _PosRetailProAppState();
}

class _PosRetailProAppState extends State<PosRetailProApp> {
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
      title: 'Nusantara POS Pro',
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
        tema: _tema,
        onGantiTema: _gantiTema,
      ),
    );
  }
}
