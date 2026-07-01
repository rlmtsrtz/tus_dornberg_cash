import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'models/person.dart';
import 'models/penalty.dart';
import 'models/app_transaction.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAQxuDNE32lHfFbGsBO-baKWUyX8Z9Rzcc",
      authDomain: "tus-dornberg-cash.firebaseapp.com",
      projectId: "tus-dornberg-cash",
      storageBucket: "tus-dornberg-cash.firebasestorage.app",
      messagingSenderId: "901821046390",
      appId: "1:901821046390:web:86e4536cd9dabbddf08957",
      measurementId: "G-9QXZ3T2EP4",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuS Dornberg Cash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
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
  int _selectedIndex = 0;
  bool _isAdmin = false;
  User? _user;
  bool _isTestDataMode = false;

  @override
  void initState() {
    super.initState();
    FirebaseService.authStateChanges.listen((user) async {
      final isAdmin = await FirebaseService.isAdmin();
      if (mounted) {
        setState(() {
          _user = user;
          _isAdmin = isAdmin;
        });
      }
    });
  }

  void _showLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Admin Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-Mail'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Passwort'),
                obscureText: true,
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                setDialogState(() => isLoading = true);
                final errorMessage = await FirebaseService.signIn(
                  emailController.text.trim(), 
                  passwordController.text
                );
                if (mounted) {
                  if (errorMessage == null) {
                    Navigator.pop(context);
                  } else {
                    setDialogState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Login fehlgeschlagen: $errorMessage')),
                    );
                  }
                }
              },
              child: const Text('Anmelden'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminManagement() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin-Verwaltung'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Neue Admin E-Mail',
                  hintText: 'beispiel@gmail.com',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Aktuelle Admins:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              StreamBuilder<List<String>>(
                stream: FirebaseService.getAdminEmails(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final admins = snapshot.data!;
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: admins.length,
                      itemBuilder: (context, index) {
                        final email = admins[index];
                        return ListTile(
                          title: Text(email, style: const TextStyle(fontSize: 14)),
                          trailing: email == 'felske.mirco@gmail.com'
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => FirebaseService.removeAdminEmail(email),
                                ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.contains('@')) {
                await FirebaseService.addAdminEmail(emailController.text.trim().toLowerCase());
                emailController.clear();
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      KassePage(isAdmin: _isAdmin || _isTestDataMode, isTestDataMode: _isTestDataMode),
      PersonenListPage(isAdmin: _isAdmin || _isTestDataMode, isTestDataMode: _isTestDataMode),
      StrafenListPage(isAdmin: _isAdmin || _isTestDataMode, isTestDataMode: _isTestDataMode),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'web/assets/logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.money),
            ),
            const SizedBox(width: 12),
            const Text(
              'TuS Dornberg Cash',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_isTestDataMode)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text('(TESTDATEN)', style: TextStyle(fontSize: 10, color: Colors.red)),
              ),
          ],
        ),
        backgroundColor: const Color(0xFFA5D6A7),
        actions: [
          if (_user == null && !_isTestDataMode)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _showLoginDialog,
              tooltip: 'Admin Login',
            )
          else ...[
            if (_user?.email == 'felske.mirco@gmail.com' && !_isTestDataMode)
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showAdminManagement,
                tooltip: 'Admin-Verwaltung',
              ),
            PopupMenuButton(
              icon: _isTestDataMode 
                  ? const CircleAvatar(child: Icon(Icons.science))
                  : CircleAvatar(
                      backgroundImage: _user?.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
                      child: _user?.photoURL == null ? const Icon(Icons.person) : null,
                    ),
              itemBuilder: (context) => [
                if (_user != null) PopupMenuItem(child: Text(_user!.email ?? '')),
                if (_isAdmin) 
                PopupMenuItem(
                  onTap: () {
                    setState(() {
                      if (_isTestDataMode) {
                        _isTestDataMode = false;
                      } else {
                        TestData.generate();
                        _isTestDataMode = true;
                      }
                    });
                  },
                  child: Text(_isTestDataMode ? 'Lade Realdaten' : 'Lade Testdaten'),
                ),
                if (_user != null)
                  PopupMenuItem(
                    onTap: () => FirebaseService.signOut(),
                    child: const Text('Abmelden'),
                  ),
              ],
            ),
          ],
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.money), label: 'Kasse'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Personen'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Strafen'),
        ],
      ),
    );
  }
}

// --- TEST DATA GENERATOR ---

class TestData {
  static List<Person> people = [];
  static List<Penalty> penalties = [];
  static List<AppTransaction> transactions = [];
  static List<String> groups = ['MG 1', 'MG 2', 'MG 3', 'MG 4', 'Trainer', 'Ersatzbank'];

  static void generate() {
    final names = [
      'Lukas Müller', 'Leon Schmidt', 'Finn Fischer', 'Elias Weber', 'Jonas Meyer',
      'Ben Wagner', 'Noah Becker', 'Paul Schulz', 'Luis Hoffmann', 'Lars Koch',
      'Julian Bauer', 'Matthias Richter', 'Simon Klein', 'Tim Wolf', 'Felix Schröder',
      'Moritz Neumann', 'Jakob Schwarz', 'David Zimmermann', 'Jan Braun', 'Hannes Krüger',
      'Philipp Hofmann', 'Bastian Hartmann', 'Kevin Lange', 'Marcel Schmitt', 'Sven Werner'
    ];

    people = List.generate(names.length, (i) => Person(
      id: 'test_p_$i',
      name: names[i],
      groups: [groups[i % groups.length]]
    ));

    penalties = [
      Penalty(id: 't1', name: 'Zuspätkommen Training', amount: 5.0, tags: ['Einzeln', 'Training'], description: 'Innerhalb der ersten 15 Min'),
      Penalty(id: 't2', name: 'Handy in der Kabine', amount: 10.0, tags: ['Einzeln', 'Disziplin'], description: 'Während der Ansprache'),
      Penalty(id: 't3', name: 'Materialdienst vergessen', amount: 15.0, tags: ['Gruppe', 'Material'], description: 'Bälle oder Hütchen'),
      Penalty(id: 't4', name: 'Trikotwäsche vergessen', amount: 20.0, tags: ['Einzeln', 'Material'], description: 'Kompletter Satz'),
      Penalty(id: 't5', name: 'Gelbe Karte (Meckern)', amount: 10.0, tags: ['Einzeln', 'Spiel'], description: 'Unsportlichkeit'),
    ];

    transactions = [];
    final random = Random();
    final seasonStart = DateTime(2025, 7, 1);
    final seasonEnd = DateTime(2026, 6, 30);
    final totalDays = seasonEnd.difference(seasonStart).inDays;

    for (var p in people) {
      int numPenalties = 3 + random.nextInt(8);
      for (int i = 0; i < numPenalties; i++) {
        final pen = penalties[random.nextInt(penalties.length)];
        final date = seasonStart.add(Duration(days: random.nextInt(totalDays)));
        
        transactions.add(AppTransaction(
          id: 'test_t_${p.id}_$i',
          personId: p.id,
          description: pen.name,
          amount: -pen.amount,
          date: date,
        ));

        if (random.nextDouble() < 0.3) {
          transactions.add(AppTransaction(
            id: 'test_til_${p.id}_$i',
            personId: p.id,
            description: 'Tilgung',
            amount: pen.amount,
            date: date.add(Duration(days: 1 + random.nextInt(10))),
            isTilgung: true,
          ));
        }
      }
    }
    transactions.sort((a, b) => b.date.compareTo(a.date));
  }

  static Stream<List<Person>> getPeopleStream() => Stream.value(people);
  static Stream<List<Penalty>> getPenaltiesStream() => Stream.value(penalties);
  static Stream<List<AppTransaction>> getTransactionsStream() => Stream.value(transactions);
  static Stream<List<String>> getGroupsStream() => Stream.value(groups);
  static Stream<Map<String, String>> getPaymentStream() => Stream.value({
    'iban': 'DE12 3456 7890 1234 5678 90',
    'name': 'Max Mustermann (Test)',
    'email': 'test@dornberg.de',
    'preferred': 'iban', // Default for test
  });
}

// --- KASSE PAGE ---

class KassePage extends StatefulWidget {
  final bool isAdmin;
  final bool isTestDataMode;
  const KassePage({super.key, required this.isAdmin, required this.isTestDataMode});

  @override
  State<KassePage> createState() => _KassePageState();
}

class _KassePageState extends State<KassePage> {
  DateTime _startDate = DateTime(DateTime.now().year, 6, 1);
  DateTime _endDate = DateTime(DateTime.now().year + 1, 5, 31);
  DateTime? _selectedMonthStart;
  String _searchQuery = '';
  String? _selectedPenaltyFilter;

  DateTime? _realStartDate;
  DateTime? _realEndDate;

  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.isTestDataMode) {
      _realStartDate = _startDate;
      _realEndDate = _endDate;
      _startDate = DateTime(2025, 7, 1);
      _endDate = DateTime(2026, 6, 30);
    } else {
      _loadSettings();
    }
  }

  @override
  void didUpdateWidget(KassePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTestDataMode != oldWidget.isTestDataMode) {
      if (widget.isTestDataMode) {
        _realStartDate = _startDate;
        _realEndDate = _endDate;
        setState(() {
          _startDate = DateTime(2025, 7, 1);
          _endDate = DateTime(2026, 6, 30);
          _selectedMonthStart = null;
        });
      } else {
        if (_realStartDate != null) {
          setState(() {
            _startDate = _realStartDate!;
            _endDate = _realEndDate!;
            _selectedMonthStart = null;
          });
        } else {
          _loadSettings();
        }
      }
    }
  }

  void _loadSettings() async {
    final settings = await FirebaseService.getSettings();
    if (settings.containsKey('seasonStart') && settings.containsKey('seasonEnd')) {
      setState(() {
        _startDate = DateTime.parse(settings['seasonStart']!);
        _endDate = DateTime.parse(settings['seasonEnd']!);
      });
    }
  }

  void _showSeasonSettings() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      if (!widget.isTestDataMode) {
        await FirebaseService.updateSettings({
          'seasonStart': picked.start.toIso8601String(),
          'seasonEnd': picked.end.toIso8601String(),
        });
        _loadSettings();
      } else {
        setState(() {
          _startDate = picked.start;
          _endDate = picked.end;
        });
      }
    }
  }

  void _showPaymentEditDialog(Map<String, String> current) {
    final ibanC = TextEditingController(text: current['iban']);
    final nameC = TextEditingController(text: current['name']);
    final emailC = TextEditingController(text: current['email']);
    String preferred = current['preferred'] ?? 'iban';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Zahlungsinformationen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: ibanC, decoration: const InputDecoration(labelText: 'IBAN')),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Kontoinhaber')),
                RadioListTile<String>(
                  title: const Text('Konto als präferiert setzen'),
                  value: 'iban',
                  groupValue: preferred,
                  onChanged: (val) => setDialogState(() => preferred = val!),
                ),
                const Divider(),
                TextField(controller: emailC, decoration: const InputDecoration(labelText: 'E-Mail (PayPal/Kontakt)')),
                RadioListTile<String>(
                  title: const Text('PayPal als präferiert setzen'),
                  value: 'email',
                  groupValue: preferred,
                  onChanged: (val) => setDialogState(() => preferred = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                if (!widget.isTestDataMode) {
                  await FirebaseService.updatePaymentInfo({
                    'iban': ibanC.text.trim(),
                    'name': nameC.text.trim(),
                    'email': emailC.text.trim(),
                    'preferred': preferred,
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatIBAN(String iban) {
    String clean = iban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    String formatted = '';
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) formatted += ' ';
      formatted += clean[i];
    }
    return formatted;
  }

  void _copyToClipboard(String text, String label, {bool cleanSpaces = false}) {
    String finalData = cleanSpaces ? text.replaceAll(' ', '') : text;
    Clipboard.setData(ClipboardData(text: finalData));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label kopiert!'), duration: const Duration(seconds: 1)),
    );
  }

  double _calculateBalance(String personId, List<AppTransaction> transactions, {String? penaltyFilter}) {
    return transactions
        .where((t) => t.personId == personId)
        .where((t) {
          if (penaltyFilter != null) {
            return t.description == penaltyFilter;
          }
          return true;
        })
        .where((t) {
          if (_selectedMonthStart != null) {
            return t.date.year == _selectedMonthStart!.year && 
                   t.date.month == _selectedMonthStart!.month;
          }
          return t.date.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                 t.date.isBefore(_endDate.add(const Duration(days: 1)));
        })
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  List<DateTime> _getSeasonMonths() {
    List<DateTime> months = [];
    DateTime current = DateTime(_startDate.year, _startDate.month, 1);
    int count = 0;
    while (current.isBefore(_endDate) && count < 24) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
      count++;
    }
    return months;
  }

  void _shareData(List<Person> people, List<AppTransaction> transactions, List<Penalty> penalties, Map<String, String> paymentInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Visualisierung teilen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_view),
              title: const Text('Alle Salden als Bild'),
              onTap: () {
                Navigator.pop(context);
                _shareVisualTable(people, transactions, paymentInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Spieler-Historie als Bild...'),
              onTap: () {
                Navigator.pop(context);
                _showPlayerShareDialog(people, transactions, penalties);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareVisualTable(List<Person> people, List<AppTransaction> transactions, Map<String, String> paymentInfo) async {
    var sorted = List<Person>.from(people)..sort((a,b) => a.name.compareTo(b.name));
    bool ibanPref = paymentInfo['preferred'] == 'iban';
    
    Widget tableWidget = Container(
      width: 350, // Ultra-compact for layout safety
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TuS Dornberg Cash - Salden", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800])),
          Text("Stand: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
          if (_selectedPenaltyFilter != null)
            Text("Filter: $_selectedPenaltyFilter", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          // Payment Info grouped
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green[100]!)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Präferierte Zahlungsmethode:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                if (ibanPref) ...[
                  Text("IBAN: ${_formatIBAN(paymentInfo['iban'] ?? '')}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("Inhaber: ${paymentInfo['name'] ?? ''}", style: const TextStyle(fontSize: 8)),
                ] else ...[
                  Text("E-Mail: ${paymentInfo['email'] ?? ''}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 6),
                const Text("Sekundäre Zahlungsmethode:", style: TextStyle(fontSize: 9, color: Colors.grey)),
                if (!ibanPref) ...[
                  Text("IBAN: ${_formatIBAN(paymentInfo['iban'] ?? '')}", style: const TextStyle(fontSize: 8)),
                  Text("Inhaber: ${paymentInfo['name'] ?? ''}", style: const TextStyle(fontSize: 7)),
                ] else ...[
                  Text("E-Mail: ${paymentInfo['email'] ?? ''}", style: const TextStyle(fontSize: 8)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1)},
            border: TableBorder.all(color: Colors.grey[200]!),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.green[50]),
                children: [
                  const Padding(padding: EdgeInsets.all(6), child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  const Padding(padding: EdgeInsets.all(6), child: Text("Betrag", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              ),
              ...sorted.map((p) {
                double bal = _calculateBalance(p.id, transactions, penaltyFilter: _selectedPenaltyFilter);
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text(p.name, style: const TextStyle(fontSize: 10))),
                    Padding(
                      padding: const EdgeInsets.all(6), 
                      child: Text(
                        "${bal.toStringAsFixed(2).replaceAll('.', ',')} €",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bal < 0 ? Colors.red : (bal > 0 ? Colors.green : Colors.black)),
                      )
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    _captureAndShare(tableWidget, "Salden_Dornberg_Cash.png");
  }

  void _showPlayerShareDialog(List<Person> people, List<AppTransaction> transactions, List<Penalty> penalties) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spieler wählen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: people.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(people[i].name),
              onTap: () {
                Navigator.pop(context);
                _showPenaltyFilterShareDialog(people[i], transactions, penalties);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showPenaltyFilterShareDialog(Person p, List<AppTransaction> transactions, List<Penalty> penalties) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter für ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Alle Transaktionen'),
              onTap: () {
                Navigator.pop(context);
                _sharePlayerVisualHistory(p, transactions);
              },
            ),
            const Divider(),
            const Text("Nach Strafe filtern:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ...penalties.map((pen) => ListTile(
              title: Text(pen.name),
              onTap: () {
                Navigator.pop(context);
                _sharePlayerVisualHistory(p, transactions, penaltyFilter: pen.name);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _sharePlayerVisualHistory(Person p, List<AppTransaction> transactions, {String? penaltyFilter}) {
    var history = transactions.where((t) => t.personId == p.id).toList();
    if (penaltyFilter != null) {
      history = history.where((t) => t.description == penaltyFilter).toList();
    }
    
    double total = history.fold(0.0, (sum, t) => sum + t.amount);

    Widget tableWidget = Container(
      width: 350,
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Historie: ${p.name}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800])),
          if (penaltyFilter != null)
            Text("Filter: $penaltyFilter", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1)},
            border: TableBorder.all(color: Colors.grey[200]!),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.green[50]),
                children: [
                  const Padding(padding: EdgeInsets.all(6), child: Text("Datum", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                  const Padding(padding: EdgeInsets.all(6), child: Text("Beschreibung", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                  const Padding(padding: EdgeInsets.all(6), child: Text("Betrag", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                ],
              ),
              ...history.map((t) => TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(6), child: Text(DateFormat('dd.MM.yy').format(t.date), style: const TextStyle(fontSize: 8))),
                  Padding(padding: const EdgeInsets.all(6), child: Text(t.description, style: const TextStyle(fontSize: 8))),
                  Padding(
                    padding: const EdgeInsets.all(6), 
                    child: Text("${t.amount.toStringAsFixed(2).replaceAll('.', ',')} €", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: t.amount < 0 ? Colors.red : Colors.green))
                  ),
                ],
              )),
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[50]),
                children: [
                  const SizedBox(),
                  const Padding(padding: EdgeInsets.all(6), child: Text("Gesamt", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                  Padding(
                    padding: const EdgeInsets.all(6), 
                    child: Text("${total.toStringAsFixed(2).replaceAll('.', ',')} €", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    _captureAndShare(tableWidget, "Historie_${p.name.replaceAll(' ', '_')}.png");
  }

  void _captureAndShare(Widget widget, String filename) async {
    // Ultra-High-Def logic: small layout, huge pixel ratio
    final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
      Material(child: widget),
      context: context,
      pixelRatio: 6, // Crisp enough for extreme zooming
    );

    if (imageBytes != null) {
      if (kIsWeb) {
        await Share.shareXFiles([XFile.fromData(imageBytes, name: filename, mimeType: 'image/png')]);
      } else {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/$filename').create();
        await imagePath.writeAsBytes(imageBytes);
        await Share.shareXFiles([XFile(imagePath.path)]);
      }
    }
  }

  void _showFilterDialog(List<Penalty> penalties) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nach Strafe filtern'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Alle anzeigen'),
                leading: Radio<String?>(
                  value: null, 
                  groupValue: _selectedPenaltyFilter, 
                  onChanged: (v) {
                    setState(() => _selectedPenaltyFilter = v);
                    Navigator.pop(context);
                  }
                ),
                onTap: () {
                  setState(() => _selectedPenaltyFilter = null);
                  Navigator.pop(context);
                },
              ),
              ...penalties.map((p) => ListTile(
                title: Text(p.name),
                leading: Radio<String?>(
                  value: p.name, 
                  groupValue: _selectedPenaltyFilter, 
                  onChanged: (v) {
                    setState(() => _selectedPenaltyFilter = v);
                    Navigator.pop(context);
                  }
                ),
                onTap: () {
                  setState(() => _selectedPenaltyFilter = p.name);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peopleStream = widget.isTestDataMode ? TestData.getPeopleStream() : FirebaseService.getPeople();
    final transStream = widget.isTestDataMode ? TestData.getTransactionsStream() : FirebaseService.getTransactions();
    final penaltyStream = widget.isTestDataMode ? TestData.getPenaltiesStream() : FirebaseService.getPenalties();
    final groupsStream = widget.isTestDataMode ? TestData.getGroupsStream() : FirebaseService.getGroups();
    final paymentStream = widget.isTestDataMode ? TestData.getPaymentStream() : FirebaseService.getPaymentInfo();

    return StreamBuilder<List<Person>>(
      stream: peopleStream,
      builder: (context, peopleSnap) {
        return StreamBuilder<List<AppTransaction>>(
          stream: transStream,
          builder: (context, transSnap) {
            return StreamBuilder<List<Penalty>>(
              stream: penaltyStream,
              builder: (context, penaltySnap) {
                return StreamBuilder<List<String>>(
                  stream: groupsStream,
                  builder: (context, groupsSnap) {
                    return StreamBuilder<Map<String, String>>(
                      stream: paymentStream,
                      builder: (context, paymentSnap) {
                        if (!peopleSnap.hasData || !transSnap.hasData || !penaltySnap.hasData || !groupsSnap.hasData || !paymentSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final paymentInfo = paymentSnap.data!;
                        final ibanPref = paymentInfo['preferred'] == 'iban';
                        
                        var filteredPeople = peopleSnap.data!
                          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                        
                        if (_searchQuery.isNotEmpty) {
                          filteredPeople = filteredPeople.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                        }

                        final seasonMonths = _getSeasonMonths();

                        return Scaffold(
                          body: Column(
                            children: [
                              Card(
                                margin: const EdgeInsets.all(12),
                                color: const Color(0xFFE8F5E9),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Zahlungsinformationen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Row(
                                            children: [
                                              if (widget.isAdmin)
                                                IconButton(
                                                  icon: const Icon(Icons.share, size: 20),
                                                  onPressed: () => _shareData(peopleSnap.data!, transSnap.data!, penaltySnap.data!, paymentInfo),
                                                  tooltip: 'Daten teilen',
                                                ),
                                              if (widget.isAdmin)
                                                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showPaymentEditDialog(paymentInfo)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      const Text('Präferierte Zahlungsmethode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (ibanPref) ...[
                                        _buildInfoRow('IBAN', _formatIBAN(paymentInfo['iban'] ?? ''), isIban: true, isBold: true),
                                        if (paymentInfo['name'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text('Inhaber: ${paymentInfo['name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                      ] else
                                        _buildInfoRow('E-Mail', paymentInfo['email'] ?? '', isBold: true),
                                      
                                      const SizedBox(height: 8),
                                      const Text('Sekundäre Zahlungsmethode:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      if (!ibanPref) ...[
                                        _buildInfoRow('IBAN', _formatIBAN(paymentInfo['iban'] ?? ''), isIban: true),
                                        if (paymentInfo['name'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text('Inhaber: ${paymentInfo['name']}', style: const TextStyle(fontSize: 11)),
                                          ),
                                      ] else
                                        _buildInfoRow('E-Mail', paymentInfo['email'] ?? ''),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: const Color(0xFFF1F8E9),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Text('Spieler & Strafen', style: TextStyle(fontWeight: FontWeight.bold)),
                                        const Spacer(),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          width: _isSearchExpanded ? 200 : 40,
                                          height: 40,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (_isSearchExpanded)
                                                Expanded(
                                                  child: TextField(
                                                    autofocus: true,
                                                    decoration: const InputDecoration(
                                                      hintText: 'Suche...',
                                                      isDense: true,
                                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                      border: OutlineInputBorder(),
                                                      prefixIcon: Icon(Icons.search, size: 18),
                                                    ),
                                                    onChanged: (val) => setState(() => _searchQuery = val),
                                                  ),
                                                ),
                                              IconButton(
                                                icon: Icon(_isSearchExpanded ? Icons.close : Icons.search, 
                                                     color: _searchQuery.isNotEmpty ? Colors.green : null),
                                                onPressed: () {
                                                  setState(() {
                                                    _isSearchExpanded = !_isSearchExpanded;
                                                    if (!_isSearchExpanded) _searchQuery = '';
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.filter_list, color: _selectedPenaltyFilter != null ? Colors.green : null),
                                          onPressed: () => _showFilterDialog(penaltySnap.data!),
                                          tooltip: 'Nach Strafe filtern',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Saison: ${DateFormat('dd.MM.yy').format(_startDate)} - ${DateFormat('dd.MM.yy').format(_endDate)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (widget.isAdmin)
                                          IconButton(
                                            icon: const Icon(Icons.calendar_month),
                                            onPressed: _showSeasonSettings,
                                          ),
                                      ],
                                    ),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          FilterChip(
                                            label: const Text('Gesamt'),
                                            selected: _selectedMonthStart == null,
                                            onSelected: (val) => setState(() => _selectedMonthStart = null),
                                            selectedColor: const Color(0xFFA5D6A7),
                                          ),
                                          const SizedBox(width: 8),
                                          ...seasonMonths.map((m) => Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: FilterChip(
                                              label: Text(DateFormat('MMM yy').format(m)),
                                              selected: _selectedMonthStart?.year == m.year && _selectedMonthStart?.month == m.month,
                                              onSelected: (val) => setState(() => _selectedMonthStart = val ? m : null),
                                              selectedColor: const Color(0xFFA5D6A7),
                                            ),
                                          )),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filteredPeople.length,
                                  itemBuilder: (context, index) {
                                    final p = filteredPeople[index];
                                    final balance = _calculateBalance(p.id, transSnap.data!, penaltyFilter: _selectedPenaltyFilter);
                                    return InkWell(
                                      onTap: () => _showHistory(context, p, transSnap.data!),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(0xFFA5D6A7),
                                          child: Text(p.name[0], style: const TextStyle(color: Colors.white)),
                                        ),
                                        title: _buildHighlightedText(p.name, _searchQuery),
                                        subtitle: Text(p.groups.join(', ')),
                                        trailing: Text(
                                          '${balance.toStringAsFixed(2).replaceAll('.', ',')} €',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: balance < 0 ? Colors.red : (balance > 0 ? Colors.green : Colors.black),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          floatingActionButton: widget.isAdmin
                              ? FloatingActionButton(
                                  onPressed: () => _addTransaction(context, peopleSnap.data!, penaltySnap.data!, transSnap.data!, groupsSnap.data!),
                                  backgroundColor: const Color(0xFF4CAF50),
                                  child: const Icon(Icons.add, color: Colors.white),
                                )
                              : null,
                        );
                      }
                    );
                  }
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text);
    final matches = query.toLowerCase();
    final lowerText = text.toLowerCase();
    
    List<TextSpan> spans = [];
    int start = 0; int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(matches, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, backgroundColor: Color(0xFFE8F5E9)),
      ));
      start = indexOfMatch + query.length;
    }
    
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(text: TextSpan(children: spans, style: const TextStyle(color: Colors.black, fontSize: 16)));
  }

  Widget _buildInfoRow(String label, String value, {bool isIban = false, bool isBold = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(child: Text('$label: $value', style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copyToClipboard(value, label, cleanSpaces: isIban),
            tooltip: '$label kopieren',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _addTransaction(BuildContext context, List<Person> people, List<Penalty> penalties, List<AppTransaction> existingTransactions, List<String> groups) {
    Person? selectedPerson;
    String? selectedGroup;
    Penalty? selectedPenalty;
    String? selectedTag;
    DateTime selectedDate = DateTime.now();
    int multiplier = 1;
    bool isGroupMode = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final modeTag = isGroupMode ? 'Gruppe' : 'Einzeln';
          final modeFiltered = penalties.where((p) => p.tags.contains(modeTag)).toList();
          final filtered = selectedTag == null ? modeFiltered : modeFiltered.where((p) => p.tags.contains(selectedTag)).toList();
          
          final allTags = modeFiltered.expand((p) => p.tags)
              .toSet()
              .where((t) => t != 'Gruppe' && t != 'Einzeln')
              .toList()..sort();

          List<Person> targetPeople = [];
          if (isGroupMode && selectedGroup != null) {
            targetPeople = people.where((p) => p.groups.contains(selectedGroup)).toList();
          } else if (!isGroupMode && selectedPerson != null) {
            targetPeople = [selectedPerson!];
          }

          return AlertDialog(
            title: const Text('Strafe/Zahlung buchen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Einzeln'),
                        selected: !isGroupMode,
                        onSelected: (val) => setDialogState(() {
                          isGroupMode = !val;
                          selectedPenalty = null;
                          selectedTag = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Gruppe'),
                        selected: isGroupMode,
                        onSelected: (val) => setDialogState(() {
                          isGroupMode = val;
                          selectedPenalty = null;
                          selectedTag = null;
                        }),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: isGroupMode
                            ? DropdownButton<String>(
                                value: selectedGroup,
                                hint: const Text('Gruppe'),
                                isExpanded: true,
                                onChanged: (val) => setDialogState(() => selectedGroup = val),
                                items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              )
                            : DropdownButton<Person>(
                                value: selectedPerson,
                                hint: const Text('Person'),
                                isExpanded: true,
                                onChanged: (val) => setDialogState(() => selectedPerson = val),
                                items: people.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (p != null) setDialogState(() => selectedDate = p);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 4,
                    children: [
                      ChoiceChip(label: const Text('Alle'), selected: selectedTag == null, onSelected: (_) => setDialogState(() => selectedTag = null)),
                      ...allTags.map((t) => ChoiceChip(label: Text(t), selected: selectedTag == t, onSelected: (v) => setDialogState(() => selectedTag = v ? t : null))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<Penalty>(
                          value: selectedPenalty,
                          hint: const Text('Strafe'),
                          isExpanded: true,
                          onChanged: (val) => setDialogState(() => selectedPenalty = val),
                          items: filtered.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: multiplier,
                        items: List.generate(10, (i) => i + 1).map((i) => DropdownMenuItem(value: i, child: Text('${i}x'))).toList(),
                        onChanged: (val) => setDialogState(() => multiplier = val!),
                      ),
                      if (!isGroupMode)
                        IconButton(
                          icon: const Icon(Icons.account_balance_wallet, color: Colors.green),
                          onPressed: () {
                            if (selectedPerson == null) return;
                            _showTilgung(context, selectedPerson!, selectedDate);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
              ElevatedButton(
                onPressed: (targetPeople.isEmpty || selectedPenalty == null)
                    ? null
                    : () async {
                        List<Person> alreadyBooked = [];
                        for (var p in targetPeople) {
                          bool exists = existingTransactions.any((t) => 
                            t.personId == p.id && 
                            t.description == selectedPenalty!.name &&
                            t.date.year == selectedDate.year &&
                            t.date.month == selectedDate.month &&
                            t.date.day == selectedDate.day);
                          if (exists) alreadyBooked.add(p);
                        }

                        if (alreadyBooked.isNotEmpty) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Bereits gebucht?'),
                              content: Text('Für ${alreadyBooked.length} Personen wurde diese Strafe am gewählten Tag bereits erfasst. Trotzdem buchen?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nein')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja, buchen')),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                        }

                        if (mounted) Navigator.pop(context);
                        for (var person in targetPeople) {
                          for (int i = 0; i < multiplier; i++) {
                            final t = AppTransaction(
                              id: '${DateTime.now().millisecondsSinceEpoch}_${person.id}_$i',
                              personId: person.id,
                              description: selectedPenalty!.name,
                              amount: -selectedPenalty!.amount,
                              date: selectedDate,
                            );
                            if (!widget.isTestDataMode) {
                              await FirebaseService.addTransaction(t);
                            } else {
                              TestData.transactions.add(t);
                            }
                          }
                        }
                        setState(() {});
                      },
                child: Text(isGroupMode ? 'Gruppe buchen' : 'Buchen'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTilgung(BuildContext context, Person person, DateTime date) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tilgung: ${person.name}'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Betrag (€)'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
              if (amount > 0) {
                final t = AppTransaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  personId: person.id,
                  description: 'Tilgung',
                  amount: amount,
                  date: date,
                  isTilgung: true,
                );
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
                if (!widget.isTestDataMode) {
                  await FirebaseService.addTransaction(t);
                } else {
                  TestData.transactions.add(t);
                  setState(() {});
                }
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, Person person, List<AppTransaction> transactions) {
    var history = transactions.where((t) => t.personId == person.id).toList();
    
    if (_selectedPenaltyFilter != null) {
      history = history.where((t) => t.description == _selectedPenaltyFilter).toList();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historie: ${person.name}', style: const TextStyle(fontSize: 18)),
            if (_selectedPenaltyFilter != null)
              Text('Filter: $_selectedPenaltyFilter', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('Keine Einträge für diesen Filter.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final t = history[index];
                    return ListTile(
                      title: Text(t.description),
                      subtitle: Text(DateFormat('dd.MM.yy').format(t.date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${t.amount.toStringAsFixed(2)} €', style: TextStyle(color: t.amount < 0 ? Colors.red : Colors.green)),
                          if (widget.isAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () async {
                                final confirm = await _showDeleteConfirm(context);
                                if (confirm == true) {
                                  if (!widget.isTestDataMode) {
                                    await FirebaseService.deleteTransaction(t.id);
                                  } else {
                                    TestData.transactions.removeWhere((item) => item.id == t.id);
                                    setState(() {});
                                  }
                                  if (mounted) Navigator.pop(context);
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wirklich löschen?'),
        content: const Text('Soll dieser Eintrag dauerhaft entfernt werden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// --- PERSONEN LIST PAGE ---

class PersonenListPage extends StatefulWidget {
  final bool isAdmin;
  final bool isTestDataMode;
  const PersonenListPage({super.key, required this.isAdmin, required this.isTestDataMode});

  @override
  State<PersonenListPage> createState() => _PersonenListPageState();
}

class _PersonenListPageState extends State<PersonenListPage> {
  @override
  Widget build(BuildContext context) {
    final peopleStream = widget.isTestDataMode ? TestData.getPeopleStream() : FirebaseService.getPeople();
    final groupsStream = widget.isTestDataMode ? TestData.getGroupsStream() : FirebaseService.getGroups();

    return StreamBuilder<List<Person>>(
      stream: peopleStream,
      builder: (context, peopleSnap) {
        return StreamBuilder<List<String>>(
          stream: groupsStream,
          builder: (context, groupsSnap) {
            if (!peopleSnap.hasData || !groupsSnap.hasData) return const Center(child: CircularProgressIndicator());
            final people = peopleSnap.data!..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            final groups = groupsSnap.data!;

            return Scaffold(
              appBar: widget.isAdmin ? AppBar(
                toolbarHeight: 40,
                backgroundColor: Colors.white,
                title: TextButton.icon(
                  onPressed: () => _manageGroups(context, groups),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Gruppen verwalten', style: TextStyle(fontSize: 12)),
                ),
              ) : null,
              body: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: Colors.grey[50],
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text('Alle Personen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: people.length,
                              itemBuilder: (context, index) {
                                final p = people[index];
                                return ListTile(
                                  title: Text(p.name),
                                  subtitle: Text(p.groups.isEmpty ? 'Keine Gruppe' : p.groups.join(', ')),
                                  onTap: widget.isAdmin ? () => _showPersonDialog(context, groups, person: p) : null,
                                  trailing: widget.isAdmin 
                                      ? IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red), 
                                          onPressed: () => _confirmDelete(context, () {
                                            if (!widget.isTestDataMode) {
                                              FirebaseService.deletePerson(p.id);
                                            } else {
                                              TestData.people.removeWhere((item) => item.id == p.id);
                                              setState(() {});
                                            }
                                          })
                                        ) 
                                      : null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('Gruppen-Übersicht', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Expanded(
                          child: ListView(
                            children: groups.map((group) {
                              final groupPeople = people.where((p) => p.groups.contains(group)).toList();
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[200]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(group, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: groupPeople.map((p) => Chip(
                                        label: Text(p.name, style: const TextStyle(fontSize: 12)),
                                        backgroundColor: const Color(0xFFF1F8E9),
                                        side: BorderSide.none,
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      )).toList(),
                                    ),
                                    if (groupPeople.isEmpty)
                                      const Text('Keine Personen', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: widget.isAdmin
                  ? FloatingActionButton(
                      onPressed: () => _showPersonDialog(context, groups),
                      backgroundColor: const Color(0xFF4CAF50),
                      child: const Icon(Icons.add, color: Colors.white),
                    )
                  : null,
            );
          }
        );
      },
    );
  }

  void _manageGroups(BuildContext context, List<String> groups) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Gruppen verwalten'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Neue Gruppe hinzufügen'),
                  onSubmitted: (val) async {
                    if (val.isNotEmpty) {
                      if (!widget.isTestDataMode) {
                        await FirebaseService.addGroup(val.trim());
                      } else {
                        TestData.groups.add(val.trim());
                        setState(() {});
                      }
                      controller.clear();
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Vorhandene Gruppen:', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        title: Text(group),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _renameGroupDialog(context, group),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _confirmDelete(context, () {
                                if (!widget.isTestDataMode) {
                                  FirebaseService.deleteGroup(group);
                                } else {
                                  TestData.groups.remove(group);
                                  setState(() {});
                                }
                              }),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
        ),
      ),
    );
  }

  void _renameGroupDialog(BuildContext context, String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"$oldName" umbenennen'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Neuer Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && controller.text != oldName) {
                if (!widget.isTestDataMode) {
                  await FirebaseService.renameGroup(oldName, controller.text.trim());
                } else {
                  final idx = TestData.groups.indexOf(oldName);
                  if (idx != -1) TestData.groups[idx] = controller.text.trim();
                  setState(() {});
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showPersonDialog(BuildContext context, List<String> availableGroups, {Person? person}) {
    final nameController = TextEditingController(text: person?.name);
    List<String> selectedGroups = person?.groups ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(person == null ? 'Person hinzufügen' : 'Person bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerLeft, child: Text('Gruppen:', style: TextStyle(fontWeight: FontWeight.bold))),
                const Divider(),
                ...availableGroups.map((g) => CheckboxListTile(
                  title: Text(g),
                  value: selectedGroups.contains(g),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selectedGroups.add(g);
                      } else {
                        selectedGroups.remove(g);
                      }
                    });
                  },
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final p = Person(
                    id: person?.id ?? DateTime.now().millisecondsSinceEpoch.toString(), 
                    name: nameController.text.trim(), 
                    groups: selectedGroups
                  );
                  if (!widget.isTestDataMode) {
                    await FirebaseService.addPerson(p);
                  } else {
                    if (person == null) {
                      TestData.people.add(p);
                    } else {
                      final idx = TestData.people.indexWhere((item) => item.id == p.id);
                      if (idx != -1) TestData.people[idx] = p;
                    }
                    setState(() {});
                  }
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Text(person == null ? 'Hinzufügen' : 'Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Function() onDelete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wirklich löschen?'),
        content: const Text('Soll dieser Eintrag dauerhaft entfernt werden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// --- STRAFEN LIST PAGE ---

class StrafenListPage extends StatefulWidget {
  final bool isAdmin;
  final bool isTestDataMode;
  const StrafenListPage({super.key, required this.isAdmin, required this.isTestDataMode});

  @override
  State<StrafenListPage> createState() => _StrafenListPageState();
}

class _StrafenListPageState extends State<StrafenListPage> {
  @override
  Widget build(BuildContext context) {
    final penaltyStream = widget.isTestDataMode ? TestData.getPenaltiesStream() : FirebaseService.getPenalties();

    return StreamBuilder<List<Penalty>>(
      stream: penaltyStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final penalties = snapshot.data!;

        return Scaffold(
          body: ListView.builder(
            itemCount: penalties.length,
            itemBuilder: (context, index) {
              final p = penalties[index];
              return InkWell(
                onTap: widget.isAdmin ? () => _showPenaltyDialog(context, penalty: p) : null,
                child: ListTile(
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.amount.toStringAsFixed(2).replaceAll('.', ',')} €'),
                      if (p.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            p.description,
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                        ),
                      if (p.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Wrap(
                            spacing: 4,
                            children: p.tags.map((tag) => Chip(
                              label: Text(tag, style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                  trailing: widget.isAdmin ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red), 
                    onPressed: () => _confirmDelete(context, () {
                      if (!widget.isTestDataMode) {
                        FirebaseService.deletePenalty(p.id);
                      } else {
                        TestData.penalties.removeWhere((item) => item.id == p.id);
                        setState(() {});
                      }
                    })
                  ) : null,
                ),
              );
            },
          ),
          floatingActionButton: widget.isAdmin
              ? FloatingActionButton(
                  onPressed: () => _showPenaltyDialog(context),
                  backgroundColor: const Color(0xFF4CAF50),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  void _showPenaltyDialog(BuildContext context, {Penalty? penalty}) {
    final nameC = TextEditingController(text: penalty?.name);
    final amountC = TextEditingController(text: penalty?.amount.toString());
    final tagsC = TextEditingController(text: penalty?.tags.join(', '));
    final descC = TextEditingController(text: penalty?.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(penalty == null ? 'Strafe hinzufügen' : 'Strafe bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: amountC, decoration: const InputDecoration(labelText: 'Betrag (€)'), keyboardType: TextInputType.number),
              TextField(controller: tagsC, decoration: const InputDecoration(labelText: 'Tags (komma-getrennt)')),
              TextField(
                controller: descC, 
                decoration: const InputDecoration(labelText: 'Erklärung', hintText: 'Kurze Beschreibung...'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isNotEmpty) {
                final p = Penalty(
                  id: penalty?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameC.text,
                  amount: double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0.0,
                  tags: tagsC.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  description: descC.text,
                );
                if (!widget.isTestDataMode) {
                  await FirebaseService.addPenalty(p);
                } else {
                  if (penalty == null) {
                    TestData.penalties.add(p);
                  } else {
                    final idx = TestData.penalties.indexWhere((item) => item.id == p.id);
                    if (idx != -1) TestData.penalties[idx] = p;
                  }
                  setState(() {});
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(penalty == null ? 'Hinzufügen' : 'Speichern'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Function() onDelete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wirklich löschen?'),
        content: const Text('Soll dieser Eintrag dauerhaft entfernt werden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
