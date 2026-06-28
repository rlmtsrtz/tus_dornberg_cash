import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/person.dart';
import '../models/penalty.dart';
import '../models/app_transaction.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- AUTHENTICATION ---

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns null on success, or an error message on failure
  static Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Unbekannter Fehler';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    // Hardcoded Super-Admin
    if (user.email == 'felske.mirco@gmail.com') return true;

    final doc = await _db.collection('admins').doc(user.email).get();
    return doc.exists;
  }

  static Future<void> addAdminEmail(String email) {
    return _db.collection('admins').doc(email).set({'addedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> removeAdminEmail(String email) {
    if (email == 'felske.mirco@gmail.com') return Future.value();
    return _db.collection('admins').doc(email).delete();
  }

  static Stream<List<String>> getAdminEmails() {
    return _db.collection('admins').snapshots().map((snap) => 
      snap.docs.map((doc) => doc.id).toList());
  }

  // --- PEOPLE ---

  static Stream<List<Person>> getPeople() {
    return _db.collection('people').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Person.fromJson({...doc.data(), 'id': doc.id})).toList());
  }

  static Future<void> addPerson(Person person) {
    return _db.collection('people').doc(person.id).set(person.toJson());
  }

  static Future<void> deletePerson(String id) {
    return _db.collection('people').doc(id).delete();
  }

  static Future<void> updatePersonGroup(String id, PersonGroup newGroup) {
    return _db.collection('people').doc(id).update({'group': newGroup.name});
  }

  // --- PENALTY ---

  static Stream<List<Penalty>> getPenalties() {
    return _db.collection('penalties').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Penalty.fromJson({...doc.data(), 'id': doc.id})).toList());
  }

  static Future<void> addPenalty(Penalty penalty) {
    return _db.collection('penalties').doc(penalty.id).set(penalty.toJson());
  }

  static Future<void> deletePenalty(String id) {
    return _db.collection('penalties').doc(id).delete();
  }

  // --- TRANSACTIONS ---

  static Stream<List<AppTransaction>> getTransactions() {
    return _db.collection('transactions').orderBy('date', descending: true).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => AppTransaction.fromJson({...doc.data(), 'id': doc.id})).toList());
  }

  static Future<void> addTransaction(AppTransaction transaction) {
    return _db.collection('transactions').doc(transaction.id).set(transaction.toJson());
  }

  // --- SETTINGS ---

  static Future<Map<String, String>> getSettings() async {
    final doc = await _db.collection('settings').doc('season').get();
    if (doc.exists) {
      return Map<String, String>.from(doc.data()!);
    }
    return {};
  }

  static Future<void> updateSettings(Map<String, String> settings) {
    return _db.collection('settings').doc('season').set(settings, SetOptions(merge: true));
  }
}
