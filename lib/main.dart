import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/features/backoffice/presentation/dashboard_page.dart';
import 'package:budget_analyzer/features/warehouse/presentation/global_expense_entry_page.dart';
import 'package:budget_analyzer/features/resident/presentation/progress_entry_page.dart';
import 'package:budget_analyzer/features/apu_loader/ui/project_management_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: '',
    anonKey: '',
  );

  runApp(
    
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EVM Budget Analyzer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const GlobalExpenseEntryPage(),
    const ProgressEntryPage(),
    const ProjectManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Gastos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.construction),
            label: 'Avance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center),
            label: 'Proyecto',
          ),
        ],
      ),
    );
  }
}
