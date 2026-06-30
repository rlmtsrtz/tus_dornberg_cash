import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  void initState() {
    super.initState();
    FirebaseService.authStateChanges.listen((user) async {
      final isAdmin = await FirebaseService.isAdmin();
      setState(() {
        _user = user;
        _isAdmin = isAdmin;
      });
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
                if (errorMessage == null) {
                  Navigator.pop(context);
                } else {
                  setDialogState(() => isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Login fehlgeschlagen: $errorMessage')),
                  );
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
      KassePage(isAdmin: _isAdmin),
      PersonenListPage(isAdmin: _isAdmin),
      StrafenListPage(isAdmin: _isAdmin),
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
          ],
        ),
        backgroundColor: const Color(0xFFA5D6A7),
        actions: [
          if (_user == null)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _showLoginDialog,
              tooltip: 'Admin Login',
            )
          else ...[
            if (_user?.email == 'felske.mirco@gmail.com')
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showAdminManagement,
                tooltip: 'Admin-Verwaltung',
              ),
            PopupMenuButton(
              icon: CircleAvatar(
                backgroundImage: _user!.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
                child: _user!.photoURL == null ? const Icon(Icons.person) : null,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(child: Text(_user!.email ?? '')),
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

// --- KASSE PAGE ---

class KassePage extends StatefulWidget {
  final bool isAdmin;
  const KassePage({super.key, required this.isAdmin});

  @override
  State<KassePage> createState() => _KassePageState();
}

class _KassePageState extends State<KassePage> {
  DateTime _startDate = DateTime(DateTime.now().year, 6, 1);
  DateTime _endDate = DateTime(DateTime.now().year + 1, 5, 31);
  DateTime? _selectedMonthStart;
  String _searchQuery = '';
  String? _selectedPenaltyFilter;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
      await FirebaseService.updateSettings({
        'seasonStart': picked.start.toIso8601String(),
        'seasonEnd': picked.end.toIso8601String(),
      });
      _loadSettings();
    }
  }

  void _showPaymentEditDialog(Map<String, String> current) {
    final ibanC = TextEditingController(text: current['iban']);
    final nameC = TextEditingController(text: current['name']);
    final emailC = TextEditingController(text: current['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zahlungsinformationen bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ibanC, decoration: const InputDecoration(labelText: 'IBAN')),
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name des Kontoinhabers')),
            TextField(controller: emailC, decoration: const InputDecoration(labelText: 'E-Mail für PayPal/Kontakt')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseService.updatePaymentInfo({
                'iban': ibanC.text.trim(),
                'name': nameC.text.trim(),
                'email': emailC.text.trim(),
              });
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label kopiert!'), duration: const Duration(seconds: 1)),
    );
  }

  double _calculateBalance(String personId, List<AppTransaction> transactions) {
    return transactions
        .where((t) => t.personId == personId)
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Person>>(
      stream: FirebaseService.getPeople(),
      builder: (context, peopleSnap) {
        return StreamBuilder<List<AppTransaction>>(
          stream: FirebaseService.getTransactions(),
          builder: (context, transSnap) {
            return StreamBuilder<List<Penalty>>(
              stream: FirebaseService.getPenalties(),
              builder: (context, penaltySnap) {
                return StreamBuilder<List<String>>(
                  stream: FirebaseService.getGroups(),
                  builder: (context, groupsSnap) {
                    return StreamBuilder<Map<String, String>>(
                      stream: FirebaseService.getPaymentInfo(),
                      builder: (context, paymentSnap) {
                        if (!peopleSnap.hasData || !transSnap.hasData || !penaltySnap.hasData || !groupsSnap.hasData || !paymentSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final paymentInfo = paymentSnap.data!;
                        
                        // Filter logic
                        var filteredPeople = peopleSnap.data!
                          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                        
                        if (_searchQuery.isNotEmpty) {
                          filteredPeople = filteredPeople.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                        }

                        if (_selectedPenaltyFilter != null) {
                          filteredPeople = filteredPeople.where((p) {
                            return transSnap.data!.any((t) => 
                              t.personId == p.id && 
                              t.description == _selectedPenaltyFilter &&
                              t.date.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                              t.date.isBefore(_endDate.add(const Duration(days: 1)))
                            );
                          }).toList();
                        }

                        final seasonMonths = _getSeasonMonths();

                        return Scaffold(
                          body: Column(
                            children: [
                              // Payment Info Card
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
                                          if (widget.isAdmin)
                                            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showPaymentEditDialog(paymentInfo)),
                                        ],
                                      ),
                                      const Divider(),
                                      _buildInfoRow('IBAN', paymentInfo['iban'] ?? ''),
                                      _buildInfoRow('Name', paymentInfo['name'] ?? ''),
                                      _buildInfoRow('E-Mail', paymentInfo['email'] ?? ''),
                                    ],
                                  ),
                                ),
                              ),
                              // Filter Section
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: const Color(0xFFF1F8E9),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            decoration: const InputDecoration(
                                              hintText: 'Name suchen...',
                                              prefixIcon: Icon(Icons.search),
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (val) => setState(() => _searchQuery = val),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        DropdownButton<String?>(
                                          value: _selectedPenaltyFilter,
                                          hint: const Text('Alle Strafen'),
                                          items: [
                                            const DropdownMenuItem(value: null, child: Text('Kein Filter')),
                                            ...penaltySnap.data!.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))),
                                          ],
                                          onChanged: (val) => setState(() => _selectedPenaltyFilter = val),
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
                                    final balance = _calculateBalance(p.id, transSnap.data!);
                                    return InkWell(
                                      onTap: () => _showHistory(context, p, transSnap.data!),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(0xFFA5D6A7),
                                          child: Text(p.name[0], style: const TextStyle(color: Colors.white)),
                                        ),
                                        title: Text(p.name),
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

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(child: Text('$label: $value', style: const TextStyle(fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copyToClipboard(value, label),
            tooltip: '$label kopieren',
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
          // Filter penalties by mode and selected tag
          final modeTag = isGroupMode ? 'Gruppe' : 'Einzeln';
          final modeFiltered = penalties.where((p) => p.tags.contains(modeTag)).toList();
          final filtered = selectedTag == null ? modeFiltered : modeFiltered.where((p) => p.tags.contains(selectedTag)).toList();
          
          // Get unique tags for the current mode, excluding "Gruppe" and "Einzeln"
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
                        // Duplicate Check
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

                        Navigator.pop(context);
                        for (var person in targetPeople) {
                          for (int i = 0; i < multiplier; i++) {
                            final t = AppTransaction(
                              id: '${DateTime.now().millisecondsSinceEpoch}_${person.id}_$i',
                              personId: person.id,
                              description: selectedPenalty!.name,
                              amount: -selectedPenalty!.amount,
                              date: selectedDate,
                            );
                            await FirebaseService.addTransaction(t);
                          }
                        }
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
                Navigator.pop(context);
                Navigator.pop(context);
                await FirebaseService.addTransaction(t);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, Person person, List<AppTransaction> transactions) {
    final history = transactions.where((t) => t.personId == person.id).toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Historie: ${person.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('Keine Einträge.')
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
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eintrag löschen?'),
                                    content: const Text('Soll dieser Eintrag wirklich dauerhaft entfernt werden?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nein')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await FirebaseService.deleteTransaction(t.id);
                                  Navigator.pop(context);
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
}

// --- PERSONEN LIST PAGE ---

class PersonenListPage extends StatelessWidget {
  final bool isAdmin;
  const PersonenListPage({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Person>>(
      stream: FirebaseService.getPeople(),
      builder: (context, peopleSnap) {
        return StreamBuilder<List<String>>(
          stream: FirebaseService.getGroups(),
          builder: (context, groupsSnap) {
            if (!peopleSnap.hasData || !groupsSnap.hasData) return const Center(child: CircularProgressIndicator());
            final people = peopleSnap.data!..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            final groups = groupsSnap.data!;

            return Scaffold(
              appBar: isAdmin ? AppBar(
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
                                  onTap: isAdmin ? () => _showPersonDialog(context, groups, person: p) : null,
                                  trailing: isAdmin 
                                      ? IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red), 
                                          onPressed: () => _confirmDelete(context, () => FirebaseService.deletePerson(p.id))
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
              floatingActionButton: isAdmin
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
                      await FirebaseService.addGroup(val.trim());
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
                              onPressed: () => _confirmDelete(context, () => FirebaseService.deleteGroup(group)),
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
                await FirebaseService.renameGroup(oldName, controller.text.trim());
                Navigator.pop(context);
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
                  Navigator.pop(context);
                  await FirebaseService.addPerson(p);
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

class StrafenListPage extends StatelessWidget {
  final bool isAdmin;
  const StrafenListPage({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Penalty>>(
      stream: FirebaseService.getPenalties(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final penalties = snapshot.data!;

        return Scaffold(
          body: ListView.builder(
            itemCount: penalties.length,
            itemBuilder: (context, index) {
              final p = penalties[index];
              return InkWell(
                onTap: isAdmin ? () => _showPenaltyDialog(context, penalty: p) : null,
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
                  trailing: isAdmin ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red), 
                    onPressed: () => _confirmDelete(context, () => FirebaseService.deletePenalty(p.id))
                  ) : null,
                ),
              );
            },
          ),
          floatingActionButton: isAdmin
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
                Navigator.pop(context);
                await FirebaseService.addPenalty(p);
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
