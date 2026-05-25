import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/format.dart';
import 'models.dart';
import 'seed.dart';

const _storageKey = 'homies-mobile-v2';

class AuthResult {
  final bool ok;
  final String? error;
  const AuthResult.success() : ok = true, error = null;
  const AuthResult.failure(this.error) : ok = false;
}

class HomiesState extends ChangeNotifier {
  Session session = SeedData.session();
  Property property = SeedData.property();
  List<User> users = SeedData.users();
  List<Invite> invites = SeedData.invites();
  List<HouseRule> houseRules = SeedData.rules();
  List<Bill> bills = SeedData.bills();
  List<BillSchedule> billSchedules = SeedData.schedules();
  List<Subscription> subscriptions = SeedData.subscriptions();
  List<Necessity> necessities = SeedData.necessities();
  List<Grocery> groceries = SeedData.groceries();
  List<CleaningRosterEntry> cleaningRoster = SeedData.roster();
  List<CleaningTask> cleaningTasks = SeedData.tasks();
  List<Party> parties = SeedData.parties();
  Messages messages = SeedData.messages();
  List<Complaint> complaints = SeedData.complaints();
  List<Issue> issues = SeedData.issues();
  List<Notice> notices = [];
  TerminationPlan? termination;

  StreamSubscription<fb.User?>? _authSub;

  User? get currentUser {
    final id = session.userId;
    if (id == null) return null;
    return users.firstWhereOrNull((u) => u.id == id);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        session = Session.fromJson((j['session'] as Map<String, dynamic>?) ?? {});
        property = j['property'] != null ? Property.fromJson(j['property'] as Map<String, dynamic>) : property;
        users = ((j['users'] as List?) ?? []).map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
        invites = ((j['invites'] as List?) ?? []).map((e) => Invite.fromJson(e as Map<String, dynamic>)).toList();
        houseRules = ((j['houseRules'] as List?) ?? []).map((e) => HouseRule.fromJson(e as Map<String, dynamic>)).toList();
        bills = ((j['bills'] as List?) ?? []).map((e) => Bill.fromJson(e as Map<String, dynamic>)).toList();
        billSchedules = ((j['billSchedules'] as List?) ?? []).map((e) => BillSchedule.fromJson(e as Map<String, dynamic>)).toList();
        subscriptions = ((j['subscriptions'] as List?) ?? []).map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();
        necessities = ((j['necessities'] as List?) ?? []).map((e) => Necessity.fromJson(e as Map<String, dynamic>)).toList();
        groceries = ((j['groceries'] as List?) ?? []).map((e) => Grocery.fromJson(e as Map<String, dynamic>)).toList();
        cleaningRoster = ((j['cleaningRoster'] as List?) ?? []).map((e) => CleaningRosterEntry.fromJson(e as Map<String, dynamic>)).toList();
        cleaningTasks = ((j['cleaningTasks'] as List?) ?? []).map((e) => CleaningTask.fromJson(e as Map<String, dynamic>)).toList();
        parties = ((j['parties'] as List?) ?? []).map((e) => Party.fromJson(e as Map<String, dynamic>)).toList();
        messages = j['messages'] != null ? Messages.fromJson(j['messages'] as Map<String, dynamic>) : messages;
        complaints = ((j['complaints'] as List?) ?? []).map((e) => Complaint.fromJson(e as Map<String, dynamic>)).toList();
        issues = ((j['issues'] as List?) ?? []).map((e) => Issue.fromJson(e as Map<String, dynamic>)).toList();
        notices = ((j['notices'] as List?) ?? []).map((e) => Notice.fromJson(e as Map<String, dynamic>)).toList();
        termination = j['termination'] != null ? TerminationPlan.fromJson(j['termination'] as Map<String, dynamic>) : null;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Failed to load persisted state: $e');
        }
      }
    }
    _startAuthListener();
  }

  void _startAuthListener() {
    _authSub?.cancel();
    _authSub = fb.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        if (session.userId != null) {
          mutate(() {
            session = Session();
          });
        }
        return;
      }
      if (session.userId == fbUser.uid && users.any((u) => u.id == fbUser.uid)) {
        return;
      }
      await _hydrateUserFromFirestore(fbUser);
    });
  }

  Future<void> _hydrateUserFromFirestore(fb.User fbUser) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(fbUser.uid).get();
      final data = snap.data();
      if (data == null) {
        // Auth user exists but no profile doc — treat as a stub.
        mutate(() {
          if (users.firstWhereOrNull((u) => u.id == fbUser.uid) == null) {
            users.add(User(
              id: fbUser.uid,
              name: fbUser.email ?? 'User',
              initials: _initialsFor(fbUser.email ?? 'U'),
              role: 'tenant',
              email: fbUser.email ?? '',
              phone: '',
              pending: true,
            ));
          }
          session = Session(userId: fbUser.uid, pendingSignup: session.pendingSignup);
        });
        return;
      }
      final remote = User(
        id: fbUser.uid,
        name: (data['name'] as String?) ?? '',
        initials: (data['initials'] as String?) ?? _initialsFor((data['name'] as String?) ?? ''),
        role: (data['role'] as String?) ?? 'tenant',
        email: (data['email'] as String?) ?? fbUser.email ?? '',
        phone: (data['phone'] as String?) ?? '',
        moveInDate: data['moveInDate'] as String?,
        moveOutDate: data['moveOutDate'] as String?,
        bondPaid: (data['bondPaid'] as bool?) ?? false,
        bondAmount: ((data['bondAmount'] as num?) ?? 0).toDouble(),
        docVerified: (data['docVerified'] as bool?) ?? false,
        advanceRentPaid: (data['advanceRentPaid'] as bool?) ?? false,
        acceptedRulesAt: data['acceptedRulesAt'] as String?,
        pending: (data['pending'] as bool?) ?? true,
      );
      mutate(() {
        final idx = users.indexWhere((u) => u.id == fbUser.uid);
        if (idx >= 0) {
          users[idx] = remote;
        } else {
          users.add(remote);
        }
        session = Session(userId: fbUser.uid, pendingSignup: session.pendingSignup);
      });
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to hydrate user from Firestore: $e');
      }
    }
  }

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone = '',
  }) async {
    try {
      final cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      final displayName = name.trim().isEmpty ? 'New user' : name.trim();
      final initials = _initialsFor(displayName);
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': displayName,
        'initials': initials,
        'role': role,
        'email': email.trim(),
        'phone': phone.trim(),
        'pending': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      mutate(() {
        users.add(User(
          id: uid,
          name: displayName,
          initials: initials,
          role: role,
          email: email.trim(),
          phone: phone.trim(),
          pending: true,
        ));
        session = Session(userId: uid, pendingSignup: {'role': role});
      });
      return const AuthResult.success();
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.failure(_authErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Sign-up failed: $e');
    }
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _hydrateUserFromFirestore(cred.user!);
      return const AuthResult.success();
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.failure(_authErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    await fb.FirebaseAuth.instance.signOut();
    mutate(() {
      session = Session();
    });
  }

  String _authErrorMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return "That email address isn't valid.";
      case 'weak-password':
        return 'Password is too weak — use at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts — wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '??';
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final j = {
      'session': session.toJson(),
      'property': property.toJson(),
      'users': users.map((u) => u.toJson()).toList(),
      'invites': invites.map((i) => i.toJson()).toList(),
      'houseRules': houseRules.map((r) => r.toJson()).toList(),
      'bills': bills.map((b) => b.toJson()).toList(),
      'billSchedules': billSchedules.map((b) => b.toJson()).toList(),
      'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
      'necessities': necessities.map((n) => n.toJson()).toList(),
      'groceries': groceries.map((g) => g.toJson()).toList(),
      'cleaningRoster': cleaningRoster.map((r) => r.toJson()).toList(),
      'cleaningTasks': cleaningTasks.map((t) => t.toJson()).toList(),
      'parties': parties.map((p) => p.toJson()).toList(),
      'messages': messages.toJson(),
      'complaints': complaints.map((c) => c.toJson()).toList(),
      'issues': issues.map((i) => i.toJson()).toList(),
      'notices': notices.map((n) => n.toJson()).toList(),
      'termination': termination?.toJson(),
    };
    await prefs.setString(_storageKey, jsonEncode(j));
  }

  void mutate(void Function() block) {
    block();
    notifyListeners();
    _persist();
  }

  void reset() {
    session = Session();
    property = SeedData.property();
    users = SeedData.users();
    invites = SeedData.invites();
    houseRules = SeedData.rules();
    bills = SeedData.bills();
    billSchedules = SeedData.schedules();
    subscriptions = SeedData.subscriptions();
    necessities = SeedData.necessities();
    groceries = SeedData.groceries();
    cleaningRoster = SeedData.roster();
    cleaningTasks = SeedData.tasks();
    parties = SeedData.parties();
    messages = SeedData.messages();
    complaints = SeedData.complaints();
    issues = SeedData.issues();
    notices = [];
    termination = null;
    notifyListeners();
    _persist();
  }

  void signIn(String userId) {
    mutate(() {
      session = Session(userId: userId, pendingSignup: session.pendingSignup);
    });
  }

  User? findUser(String? id) {
    if (id == null) return null;
    return users.firstWhereOrNull((u) => u.id == id);
  }

  List<User> get activeHousemates =>
      users.where((u) => !u.pending && (u.moveOutDate == null || u.moveOutDate!.isEmpty)).toList();

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class HomiesScope extends InheritedNotifier<HomiesState> {
  const HomiesScope({super.key, required HomiesState state, required super.child})
      : super(notifier: state);

  static HomiesState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HomiesScope>();
    assert(scope != null, 'HomiesScope.of() called with a context that does not contain a HomiesScope');
    return scope!.notifier!;
  }
}
