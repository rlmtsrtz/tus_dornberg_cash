import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/person.dart';
import 'models/penalty.dart';
import 'models/app_transaction.dart';
import 'services/google_sheets_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuS Dornberg Cash',
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
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    KassePage(),
    PersonenListPage(),
    StrafenListPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TuS Dornberg Cash'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _pages[_selectedIndex],
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
  const KassePage({super.key});

  @override
  State<KassePage> createState() => _KassePageState();
}

class _KassePageState extends State<KassePage> {
  List<Person> _people = [];
  List<AppTransaction> _transactions = [];
  List<Penalty> _penalties = [];
  bool _isLoading = true;

  DateTime _startDate = DateTime(DateTime.now().year, 6, 1);
  DateTime _endDate = DateTime(DateTime.now().year + 1, 5, 31);
  
  // For monthly filtering: null means "Gesamt", otherwise store the specific start of the month
  DateTime? _selectedMonthStart;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final people = await GoogleSheetsService.getPeople();
    final transactions = await GoogleSheetsService.getTransactions();
    final penalties = await GoogleSheetsService.getPenalties();
    final settings = await GoogleSheetsService.getSettings();

    if (settings.containsKey('seasonStart') && settings.containsKey('seasonEnd')) {
      _startDate = DateTime.parse(settings['seasonStart']!);
      _endDate = DateTime.parse(settings['seasonEnd']!);
    }

    setState(() {
      _people = people;
      _transactions = transactions;
      _penalties = penalties;
      _isLoading = false;
    });
  }

  void _showSeasonSettings() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() => _isLoading = true);
      await GoogleSheetsService.updateSettings({
        'seasonStart': picked.start.toIso8601String(),
        'seasonEnd': picked.end.toIso8601String(),
      });
      _loadAllData();
    }
  }

  double _calculateBalance(String personId) {
    return _transactions
        .where((t) => t.personId == personId)
        .where((t) {
          if (_selectedMonthStart != null) {
            final nextMonth = DateTime(_selectedMonthStart!.year, _selectedMonthStart!.month + 1, 1);
            return t.date.isAtSameMomentAs(_selectedMonthStart!) || 
                   (t.date.isAfter(_selectedMonthStart!) && t.date.isBefore(nextMonth));
          }
          // Default: Season range
          return t.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
                 t.date.isBefore(_endDate.add(const Duration(days: 1)));
        })
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Generates months based on season start
  List<DateTime> _getSeasonMonths() {
    List<DateTime> months = [];
    DateTime current = DateTime(_startDate.year, _startDate.month, 1);
    while (current.isBefore(_endDate)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }

  void _addTransactionDialog() {
    Person? selectedPerson;
    Penalty? selectedPenalty;
    String? selectedTag;

    // Get all unique tags from available penalties
    final allTags = _penalties.expand((p) => p.tags).toSet().toList()..sort();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter penalties by selected tag
          final filteredPenalties = selectedTag == null 
              ? _penalties 
              : _penalties.where((p) => p.tags.contains(selectedTag)).toList();

          return AlertDialog(
            title: const Text('Strafe/Zahlung buchen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<Person>(
                    value: selectedPerson,
                    hint: const Text('Person wählen'),
                    isExpanded: true,
                    onChanged: (val) => setDialogState(() => selectedPerson = val),
                    items: _people.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Filter nach Tag:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Alle', style: TextStyle(fontSize: 10)),
                          selected: selectedTag == null,
                          onSelected: (val) => setDialogState(() => selectedTag = null),
                        ),
                        ...allTags.map((tag) => Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: ChoiceChip(
                            label: Text(tag, style: const TextStyle(fontSize: 10)),
                            selected: selectedTag == tag,
                            onSelected: (val) {
                              setDialogState(() {
                                selectedTag = val ? tag : null;
                                selectedPenalty = null; // Reset selection if filtered out
                              });
                            },
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<Penalty>(
                          value: selectedPenalty,
                          hint: const Text('Strafe wählen'),
                          isExpanded: true,
                          onChanged: (val) => setDialogState(() => selectedPenalty = val),
                          items: filteredPenalties.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_balance_wallet, color: Colors.green),
                        tooltip: 'Tilgung',
                        onPressed: () {
                          if (selectedPerson == null) return;
                          _showTilgungDialog(selectedPerson!);
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
                onPressed: (selectedPerson == null || selectedPenalty == null) ? null : () async {
                  final trans = AppTransaction(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    personId: selectedPerson!.id,
                    description: selectedPenalty!.name,
                    amount: -selectedPenalty!.amount, 
                    date: DateTime.now(),
                  );
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  await GoogleSheetsService.addTransaction(trans);
                  _loadAllData();
                },
                child: const Text('Buchen'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTilgungDialog(Person person) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tilgung für ${person.name}'),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(labelText: 'Betrag (€)', hintText: 'z.B. 10.00'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              final amountStr = amountController.text.replaceAll(',', '.');
              final amount = double.tryParse(amountStr) ?? 0.0;
              if (amount > 0) {
                final trans = AppTransaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  personId: person.id,
                  description: 'Tilgung',
                  amount: amount, 
                  date: DateTime.now(),
                  isTilgung: true,
                );
                Navigator.pop(context); // Close Tilgung dialog
                Navigator.pop(context); // Close Add dialog
                setState(() => _isLoading = true);
                await GoogleSheetsService.addTransaction(trans);
                _loadAllData();
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final seasonMonths = _getSeasonMonths();

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue[50],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saison: ${DateFormat('dd.MM.yy').format(_startDate)} - ${DateFormat('dd.MM.yy').format(_endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: _showSeasonSettings,
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Gesamt', style: TextStyle(fontSize: 12)),
                        selected: _selectedMonthStart == null,
                        onSelected: (val) => setState(() => _selectedMonthStart = null),
                      ),
                      const SizedBox(width: 8),
                      ...seasonMonths.map((monthStart) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(
                              DateFormat('MMM yy').format(monthStart),
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _selectedMonthStart != null && 
                                      _selectedMonthStart!.year == monthStart.year && 
                                      _selectedMonthStart!.month == monthStart.month,
                            onSelected: (val) => setState(() => _selectedMonthStart = val ? monthStart : null),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _people.length,
              itemBuilder: (context, index) {
                final p = _people[index];
                final balance = _calculateBalance(p.id);
                return ListTile(
                  leading: CircleAvatar(child: Text(p.name[0])),
                  title: Text(p.name),
                  subtitle: Text(p.group.displayName),
                  trailing: Text(
                    '${balance.toStringAsFixed(2).replaceAll('.', ',')} €',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: balance < 0 ? Colors.red : (balance > 0 ? Colors.green : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransactionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- PERSONEN LIST PAGE (Drag & Drop) ---

class PersonenListPage extends StatefulWidget {
  const PersonenListPage({super.key});

  @override
  State<PersonenListPage> createState() => _PersonenListPageState();
}

class _PersonenListPageState extends State<PersonenListPage> {
  List<Person> _people = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoading = true);
    final people = await GoogleSheetsService.getPeople();
    setState(() {
      _people = people;
      _isLoading = false;
    });
  }

  void _showAddPersonDialog() {
    final nameController = TextEditingController();
    PersonGroup selectedGroup = PersonGroup.ersatzbank;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Person hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButton<PersonGroup>(
                value: selectedGroup,
                isExpanded: true,
                onChanged: (val) => setDialogState(() => selectedGroup = val!),
                items: PersonGroup.values.map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(g.displayName),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final newPerson = Person(
                    id: DateTime.now().millisecondsSinceEpoch.toString(), 
                    name: name, 
                    group: selectedGroup
                  );
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  await GoogleSheetsService.addPerson(newPerson);
                  _loadPeople();
                }
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Personen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _people.length,
                      itemBuilder: (context, index) {
                        final p = _people[index];
                        return Draggable<Person>(
                          data: p,
                          feedback: Material(
                            elevation: 4,
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(16),
                              color: Colors.blue[100],
                              child: Text(p.name),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.5,
                            child: ListTile(title: Text(p.name)),
                          ),
                          child: ListTile(
                            title: Text(p.name),
                            subtitle: Text(p.group.displayName),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                await GoogleSheetsService.deletePerson(p.id);
                                _loadPeople();
                              },
                            ),
                          ),
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
                  padding: EdgeInsets.all(8.0),
                  child: Text('Gruppen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Expanded(
                  child: ListView(
                    children: PersonGroup.values.map((group) {
                      final groupPeople = _people.where((p) => p.group == group).toList();
                      return DragTarget<Person>(
                        onWillAccept: (data) => data?.group != group,
                        onAccept: (person) async {
                          setState(() => _isLoading = true);
                          await GoogleSheetsService.updatePersonGroup(person.id, group);
                          _loadPeople();
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: candidateData.isNotEmpty ? Colors.blue[50] : Colors.white,
                              border: Border.all(color: candidateData.isNotEmpty ? Colors.blue : Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(group.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: groupPeople.map((p) => Chip(
                                    label: Text(p.name, style: const TextStyle(fontSize: 12)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  )).toList(),
                                ),
                                if (groupPeople.isEmpty)
                                  const Text('Keine Personen', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPersonDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- STRAFEN LIST PAGE ---

class StrafenListPage extends StatefulWidget {
  const StrafenListPage({super.key});

  @override
  State<StrafenListPage> createState() => _StrafenListPageState();
}

class _StrafenListPageState extends State<StrafenListPage> {
  List<Penalty> _penalties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPenalties();
  }

  Future<void> _loadPenalties() async {
    setState(() => _isLoading = true);
    final penalties = await GoogleSheetsService.getPenalties();
    setState(() {
      _penalties = penalties;
      _isLoading = false;
    });
  }

  void _showAddPenaltyDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final tagController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Strafe hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Bezeichnung'),
              autofocus: true,
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Höhe (€)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: tagController,
              decoration: const InputDecoration(labelText: 'Tags (kommagetrennt)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final amountStr = amountController.text.replaceAll(',', '.');
              final amount = double.tryParse(amountStr) ?? 0.0;
              final tags = tagController.text.isEmpty 
                  ? <String>[] 
                  : tagController.text.split(',').map((e) => e.trim()).toList();

              if (name.isNotEmpty) {
                final newPenalty = Penalty(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), 
                  name: name, 
                  amount: amount,
                  tags: tags,
                );
                Navigator.pop(context);
                setState(() => _isLoading = true);
                await GoogleSheetsService.addPenalty(newPenalty);
                _loadPenalties();
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
    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _penalties.isEmpty
            ? const Center(child: Text('Noch keine Strafen definiert.'))
            : ListView.builder(
              itemCount: _penalties.length,
              itemBuilder: (context, index) {
                final p = _penalties[index];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.amount.toStringAsFixed(2).replaceAll('.', ',')} €'),
                      if (p.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Wrap(
                            spacing: 4,
                            children: p.tags.map((t) => Chip(
                              label: Text(t, style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await GoogleSheetsService.deletePenalty(p.id);
                      _loadPenalties();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPenaltyDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
