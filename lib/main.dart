import 'package:flutter/material.dart';
import 'models/person.dart';
import 'models/penalty.dart';
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
  int _selectedIndex = 1; // Start with People list

  static const List<Widget> _pages = [
    Center(child: Text('Kasse (Demnächst)')),
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
    PersonGroup selectedGroup = PersonGroup.mg1;

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
    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _people.isEmpty 
            ? const Center(child: Text('Noch keine Personen angelegt.'))
            : ListView.builder(
              itemCount: _people.length,
              itemBuilder: (context, index) {
                final p = _people[index];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text(p.group.displayName),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await GoogleSheetsService.deletePerson(p.id);
                      _loadPeople();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPersonDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Strafe hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Bezeichnung (z.B. Zuspätkommen)'),
              autofocus: true,
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Höhe (€)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              if (name.isNotEmpty) {
                final newPenalty = Penalty(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), 
                  name: name, 
                  amount: amount
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
                  subtitle: Text('${p.amount.toStringAsFixed(2).replaceAll('.', ',')} €'),
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
