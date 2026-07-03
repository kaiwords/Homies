import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../util/admin_api.dart';
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
  List<CleaningDayAvailability> cleaningAvailability = [];
  List<ChoreSwapRequest> choreSwaps = SeedData.choreSwaps();
  List<RentShare> rentShares = [];
  List<RentPayment> rentPayments = SeedData.rentPayments();
  List<Party> parties = SeedData.parties();
  Messages messages = SeedData.messages();
  List<Complaint> complaints = SeedData.complaints();
  List<Issue> issues = SeedData.issues();
  List<Notice> notices = [];
  TerminationPlan? termination;
  List<Listing> listings = SeedData.listings();
  List<ListingInterest> listingInterests = SeedData.listingInterests();
  List<Inspection> inspections = SeedData.inspections();
  List<PostMessage> postMessages = SeedData.postMessages();
  List<PersonalExpense> personalExpenses = SeedData.personalExpenses();
  List<MaintenanceContact> maintenanceContacts = SeedData.maintenanceContacts();
  List<ShoppingItem> shoppingList = SeedData.shoppingList();
  WelcomeGuide welcomeGuide = SeedData.welcomeGuide();
  NotificationPrefs notifPrefs = NotificationPrefs();
  // Which essentials categories this device's user wants to browse. Empty
  // means "no preference set yet" — show all categories (unchanged default).
  List<String> essentialCategoryPrefs = [];
  List<String> goodsCategoryPrefs = [];
  List<CalendarNote> calendarNotes = [];
  List<AppNotification> appNotifications = [];
  List<LeaseholderReview> lhReviews = [];
  HouseTerms houseTerms = HouseTerms();
  List<ConditionCheck> conditionChecks = [];
  List<ApplianceBooking> applianceBookings = [];
  List<ParkingBooking> parkingBookings = [];
  List<EssentialListing> essentials = [];
  List<EssentialBooking> essentialBookings = [];
  List<GoodsListing> goodsListings = [];

  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _houseSub;
  String? _syncedHouseId;
  bool _applyingRemoteHouse = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _globalSub;
  bool _globalSyncing = false;
  bool _applyingRemoteGlobal = false;

  // Every real account, admin-only (authorized by the isAdmin() Firestore
  // rule) — session-only, not part of the persisted local-storage blob.
  List<User> adminAllUsers = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _adminUsersSub;

  User? get currentUser {
    final id = session.userId;
    if (id == null) return null;
    return users.firstWhereOrNull((u) => u.id == id);
  }

  /// The house the current user belongs to, if any. Null for browsers, demo
  /// accounts, and leaseholders who haven't finished onboarding yet — in all
  /// those cases the app behaves exactly as it did before Firestore sync
  /// existed (pure local persistence).
  String? get houseId => currentUser?.houseId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _applyLocalOnlyFieldsFromJson(j);
        _applySharedFieldsFromJson(j);
        _applyGlobalFieldsFromJson(j);
        notifyListeners();
        _maybeAutoJoinFromAcceptedInterest();
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Failed to load persisted state: $e');
        }
      }
    }
    _startAuthListener();
  }

  // ── House-wide (shared, syncs to Firestore) fields ──────────────────────
  // Deserializes everything EXCEPT session/notifPrefs/welcomeGuide/
  // appNotifications. Shared by load() (from the local SharedPreferences
  // cache) and the house-doc snapshot listener (from Firestore) so there's
  // exactly one place that knows how to parse each field.
  void _applySharedFieldsFromJson(Map<String, dynamic> j) {
    property = j['property'] != null ? Property.fromJson(j['property'] as Map<String, dynamic>) : property;
    final rawUsers = ((j['users'] as List?) ?? []).map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    // Deduplicate by id — last entry wins (most recently written is most up-to-date).
    final userMap = <String, User>{};
    for (final u in rawUsers) { userMap[u.id] = u; }
    users = userMap.values.toList();
    invites = ((j['invites'] as List?) ?? []).map((e) => Invite.fromJson(e as Map<String, dynamic>)).toList();
    houseRules = ((j['houseRules'] as List?) ?? []).map((e) => HouseRule.fromJson(e as Map<String, dynamic>)).toList();
    bills = ((j['bills'] as List?) ?? []).map((e) => Bill.fromJson(e as Map<String, dynamic>)).toList();
    billSchedules = ((j['billSchedules'] as List?) ?? []).map((e) => BillSchedule.fromJson(e as Map<String, dynamic>)).toList();
    subscriptions = ((j['subscriptions'] as List?) ?? []).map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();
    necessities = ((j['necessities'] as List?) ?? []).map((e) => Necessity.fromJson(e as Map<String, dynamic>)).toList();
    groceries = ((j['groceries'] as List?) ?? []).map((e) => Grocery.fromJson(e as Map<String, dynamic>)).toList();
    cleaningRoster = ((j['cleaningRoster'] as List?) ?? []).map((e) => CleaningRosterEntry.fromJson(e as Map<String, dynamic>)).toList();
    cleaningTasks = ((j['cleaningTasks'] as List?) ?? []).map((e) => CleaningTask.fromJson(e as Map<String, dynamic>)).toList();
    cleaningAvailability = ((j['cleaningAvailability'] as List?) ?? []).map((e) => CleaningDayAvailability.fromJson(e as Map<String, dynamic>)).toList();
    choreSwaps = ((j['choreSwaps'] as List?) ?? []).map((e) => ChoreSwapRequest.fromJson(e as Map<String, dynamic>)).toList();
    rentShares = ((j['rentShares'] as List?) ?? []).map((e) => RentShare.fromJson(e as Map<String, dynamic>)).toList();
    rentPayments = ((j['rentPayments'] as List?) ?? []).map((e) => RentPayment.fromJson(e as Map<String, dynamic>)).toList();
    parties = ((j['parties'] as List?) ?? []).map((e) => Party.fromJson(e as Map<String, dynamic>)).toList();
    messages = j['messages'] != null ? Messages.fromJson(j['messages'] as Map<String, dynamic>) : messages;
    complaints = ((j['complaints'] as List?) ?? []).map((e) => Complaint.fromJson(e as Map<String, dynamic>)).toList();
    issues = ((j['issues'] as List?) ?? []).map((e) => Issue.fromJson(e as Map<String, dynamic>)).toList();
    notices = ((j['notices'] as List?) ?? []).map((e) => Notice.fromJson(e as Map<String, dynamic>)).toList();
    termination = j['termination'] != null ? TerminationPlan.fromJson(j['termination'] as Map<String, dynamic>) : null;
    personalExpenses = ((j['personalExpenses'] as List?) ?? []).map((e) => PersonalExpense.fromJson(e as Map<String, dynamic>)).toList();
    maintenanceContacts = ((j['maintenanceContacts'] as List?) ?? SeedData.maintenanceContacts().map((c) => c.toJson()).toList()).map((e) => MaintenanceContact.fromJson(e as Map<String, dynamic>)).toList();
    shoppingList = ((j['shoppingList'] as List?) ?? []).map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>)).toList();
    calendarNotes = ((j['calendarNotes'] as List?) ?? []).map((e) => CalendarNote.fromJson(e as Map<String, dynamic>)).toList();
    lhReviews = ((j['lhReviews'] as List?) ?? []).map((e) => LeaseholderReview.fromJson(e as Map<String, dynamic>)).toList();
    if (j['houseTerms'] != null) houseTerms = HouseTerms.fromJson(j['houseTerms'] as Map<String, dynamic>);
    conditionChecks = ((j['conditionChecks'] as List?) ?? []).map((e) => ConditionCheck.fromJson(e as Map<String, dynamic>)).toList();
    applianceBookings = ((j['applianceBookings'] as List?) ?? []).map((e) => ApplianceBooking.fromJson(e as Map<String, dynamic>)).toList();
    parkingBookings = ((j['parkingBookings'] as List?) ?? []).map((e) => ParkingBooking.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Community-wide (global, syncs to community/global) fields ───────────
  // Marketplace/essentials data — visible across all houses and to browsers
  // with no house yet, so it can't live inside a single house's document.
  void _applyGlobalFieldsFromJson(Map<String, dynamic> j) {
    // Listings — merge persisted with seed so new seed entries always appear.
    final loadedListings = ((j['listings'] as List?) ?? []).map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
    final listingIds = loadedListings.map((l) => l.id).toSet();
    listings = [...loadedListings, ...SeedData.listings().where((l) => !listingIds.contains(l.id))];
    listingInterests = ((j['listingInterests'] as List?) ?? []).map((e) => ListingInterest.fromJson(e as Map<String, dynamic>)).toList();
    inspections = ((j['inspections'] as List?) ?? []).map((e) => Inspection.fromJson(e as Map<String, dynamic>)).toList();
    // PostMessages — merge persisted with seed so demo conversations always load.
    final loadedPMs = ((j['postMessages'] as List?) ?? []).map((e) => PostMessage.fromJson(e as Map<String, dynamic>)).toList();
    final pmIds = loadedPMs.map((m) => m.id).toSet();
    postMessages = [...loadedPMs, ...SeedData.postMessages().where((m) => !pmIds.contains(m.id))];
    essentials = ((j['essentials'] as List?) ?? []).map((e) => EssentialListing.fromJson(e as Map<String, dynamic>)).toList();
    essentialBookings = ((j['essentialBookings'] as List?) ?? []).map((e) => EssentialBooking.fromJson(e as Map<String, dynamic>)).toList();
    appNotifications = ((j['appNotifications'] as List?) ?? []).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    goodsListings = ((j['goodsListings'] as List?) ?? []).map((e) => GoodsListing.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> _globalFieldsJson() => {
        'listings': listings.map((l) => l.toJson()).toList(),
        'listingInterests': listingInterests.map((i) => i.toJson()).toList(),
        'inspections': inspections.map((i) => i.toJson()).toList(),
        'postMessages': postMessages.map((m) => m.toJson()).toList(),
        'essentials': essentials.map((e) => e.toJson()).toList(),
        'essentialBookings': essentialBookings.map((b) => b.toJson()).toList(),
        'appNotifications': appNotifications.map((n) => n.toJson()).toList(),
        'goodsListings': goodsListings.map((g) => g.toJson()).toList(),
      };

  Map<String, dynamic> _sharedFieldsJson() => {
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
        'cleaningAvailability': cleaningAvailability.map((a) => a.toJson()).toList(),
        'choreSwaps': choreSwaps.map((r) => r.toJson()).toList(),
        'rentShares': rentShares.map((r) => r.toJson()).toList(),
        'rentPayments': rentPayments.map((p) => p.toJson()).toList(),
        'parties': parties.map((p) => p.toJson()).toList(),
        'messages': messages.toJson(),
        'complaints': complaints.map((c) => c.toJson()).toList(),
        'issues': issues.map((i) => i.toJson()).toList(),
        'notices': notices.map((n) => n.toJson()).toList(),
        'termination': termination?.toJson(),
        'personalExpenses': personalExpenses.map((e) => e.toJson()).toList(),
        'maintenanceContacts': maintenanceContacts.map((c) => c.toJson()).toList(),
        'shoppingList': shoppingList.map((i) => i.toJson()).toList(),
        'calendarNotes': calendarNotes.map((n) => n.toJson()).toList(),
        'lhReviews': lhReviews.map((r) => r.toJson()).toList(),
        'houseTerms': houseTerms.toJson(),
        'conditionChecks': conditionChecks.map((c) => c.toJson()).toList(),
        'applianceBookings': applianceBookings.map((b) => b.toJson()).toList(),
        'parkingBookings': parkingBookings.map((b) => b.toJson()).toList(),
      };

  // ── Local-only (per-device, never syncs to Firestore) fields ────────────
  void _applyLocalOnlyFieldsFromJson(Map<String, dynamic> j) {
    session = Session.fromJson((j['session'] as Map<String, dynamic>?) ?? {});
    if (j['welcomeGuide'] != null) welcomeGuide = WelcomeGuide.fromJson(j['welcomeGuide'] as Map<String, dynamic>);
    if (j['notifPrefs'] != null) notifPrefs = NotificationPrefs.fromJson(j['notifPrefs'] as Map<String, dynamic>);
    essentialCategoryPrefs = List<String>.from((j['essentialCategoryPrefs'] as List?) ?? []);
    goodsCategoryPrefs = List<String>.from((j['goodsCategoryPrefs'] as List?) ?? []);
  }

  Map<String, dynamic> _localOnlyFieldsJson() => {
        'session': session.toJson(),
        'welcomeGuide': welcomeGuide.toJson(),
        'notifPrefs': notifPrefs.toJson(),
        'essentialCategoryPrefs': essentialCategoryPrefs,
        'goodsCategoryPrefs': goodsCategoryPrefs,
      };

  void _startAuthListener() {
    _authSub?.cancel();
    _authSub = fb.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        if (session.userId != null) {
          stopHouseSync();
          stopGlobalSync();
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
              member: false,
            ));
          }
          session = Session(userId: fbUser.uid, pendingSignup: session.pendingSignup);
        });
        startGlobalSync(); // even a pending/incomplete signup should see the marketplace
        return;
      }
      final remote = User.fromFirestoreDoc(fbUser.uid, data);
      if (remote.email.isEmpty && fbUser.email != null) remote.email = fbUser.email!;
      mutate(() {
        final idx = users.indexWhere((u) => u.id == fbUser.uid);
        if (idx >= 0) {
          users[idx] = remote;
        } else {
          users.add(remote);
        }
        session = Session(userId: fbUser.uid, pendingSignup: session.pendingSignup);
      });
      startGlobalSync();
      if (remote.houseId == null) _maybeAutoJoinFromAcceptedInterest();
      if (remote.houseId != null) {
        startHouseSync(remote.houseId!);
      } else if (remote.role == 'leaseholder' && property.setupComplete) {
        // A leaseholder who finished onboarding before house sync existed —
        // retroactively create their house doc, seeded from whatever local
        // data this device already has, instead of routing them back
        // through onboarding UI. One-time: never fires again once houseId
        // is set.
        createHouse().catchError((Object e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('Retroactive createHouse() failed: $e');
          }
          return '';
        });
      }
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
    bool member = false,
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
        'member': member,
        'createdAt': FieldValue.serverTimestamp(),
      });
      mutate(() {
        if (users.firstWhereOrNull((u) => u.id == uid) == null) {
          users.add(User(
            id: uid,
            name: displayName,
            initials: initials,
            role: role,
            email: email.trim(),
            phone: phone.trim(),
            pending: true,
            member: member,
          ));
        }
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
    stopHouseSync();
    stopGlobalSync();
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
    final j = {..._sharedFieldsJson(), ..._localOnlyFieldsJson(), ..._globalFieldsJson()};
    await prefs.setString(_storageKey, jsonEncode(j));
    _pushHouseDocIfNeeded();
    _pushGlobalDocIfNeeded();
  }

  // ── Firestore whole-house sync ──────────────────────────────────────────
  // Pushes the SHARED fields to houses/{houseId} whenever local state
  // changes (called from _persist(), i.e. on every mutate()). Fire-and-forget,
  // same as the SharedPreferences write above — offline edits still succeed
  // locally and Firestore catches up on reconnect.
  void _pushHouseDocIfNeeded() {
    if (_applyingRemoteHouse) return; // this write originated from the listener itself — skip
    final id = houseId;
    if (id == null) return; // no house yet — pure local persistence, unchanged behavior
    FirebaseFirestore.instance.collection('houses').doc(id).set({
      ..._sharedFieldsJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': session.userId,
    }, SetOptions(merge: true)).catchError((Object e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to push house doc: $e');
      }
    });
  }

  /// Starts listening for remote changes to houses/{id}. Safe to call
  /// repeatedly — a no-op if already synced to this house.
  void startHouseSync(String id) {
    if (_syncedHouseId == id && _houseSub != null) return;
    _houseSub?.cancel();
    _syncedHouseId = id;
    _houseSub = FirebaseFirestore.instance.collection('houses').doc(id).snapshots().listen(
      (snap) {
        if (snap.metadata.hasPendingWrites) return; // optimistic echo of our own write
        final data = snap.data();
        if (data == null) return;
        _applyingRemoteHouse = true;
        try {
          _applySharedFieldsFromJson(data);
          notifyListeners();
          _persist();
        } finally {
          _applyingRemoteHouse = false;
        }
      },
      onError: (Object e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('House sync error: $e');
        }
      },
    );
  }

  // ── Firestore community/global sync (marketplace + essentials) ──────────
  // Same whole-document pattern as the house sync above, but for one
  // well-known doc shared by every signed-in user regardless of houseId —
  // marketplace/essentials data isn't scoped to a single house.
  void _pushGlobalDocIfNeeded() {
    // Gate on _globalSyncing (not just _applyingRemoteGlobal), same as the
    // house push gates on houseId — otherwise a demo account (or a real user
    // before startGlobalSync() has run) would attempt to push local/seed
    // data into the real shared marketplace doc on every mutate().
    if (_applyingRemoteGlobal || !_globalSyncing) return;
    FirebaseFirestore.instance.collection('community').doc('global').set({
      ..._globalFieldsJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': session.userId,
    }, SetOptions(merge: true)).catchError((Object e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to push global doc: $e');
      }
    });
  }

  /// Starts listening for remote changes to community/global. Safe to call
  /// repeatedly. Unlike house sync, this has no id parameter — there's only
  /// ever one global doc.
  void startGlobalSync() {
    if (_globalSyncing && _globalSub != null) return;
    _globalSub?.cancel();
    _globalSyncing = true;
    _globalSub = FirebaseFirestore.instance.collection('community').doc('global').snapshots().listen(
      (snap) {
        if (snap.metadata.hasPendingWrites) return;
        final data = snap.data();
        if (data == null) return;
        _applyingRemoteGlobal = true;
        try {
          _applyGlobalFieldsFromJson(data);
          notifyListeners();
          _persist();
          _maybeAutoJoinFromAcceptedInterest();
        } finally {
          _applyingRemoteGlobal = false;
        }
      },
      onError: (Object e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Global sync error: $e');
        }
      },
    );
  }

  void stopGlobalSync() {
    _globalSub?.cancel();
    _globalSub = null;
    _globalSyncing = false;
  }

  void stopHouseSync() {
    _houseSub?.cancel();
    _houseSub = null;
    _syncedHouseId = null;
  }

  String _hid() => 'h-${Random().nextInt(0xFFFFFF).toRadixString(36)}';

  /// Creates a new house doc seeded from the CURRENT local state (so any
  /// existing local/demo data becomes the house's starting content — nothing
  /// is discarded), makes the current user its first member, and starts
  /// syncing to it.
  Future<String> createHouse() async {
    final cu = currentUser;
    if (cu == null) throw StateError('createHouse() requires a signed-in user');
    final id = _hid();
    await FirebaseFirestore.instance.collection('houses').doc(id).set({
      ..._sharedFieldsJson(),
      'members': [cu.id],
      'createdBy': cu.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': cu.id,
    });
    await FirebaseFirestore.instance.collection('users').doc(cu.id).update({'houseId': id});
    mutate(() {
      currentUser?.houseId = id;
    });
    startHouseSync(id);
    return id;
  }

  /// Creates an invite: always added to local state (unchanged shape/format),
  /// and — once a house exists — also written to Firestore so the code can
  /// be redeemed on a different device. Returns the created Invite so callers
  /// (e.g. to build a shareable message) don't need to re-derive the code.
  Future<Invite> createInvite({required String email, String? phone, required String role}) async {
    final code = 'HMI-${Random().nextInt(0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final invite = Invite(code: code, email: email, phone: phone, role: role, sentAt: todayIso());
    mutate(() => invites.add(invite));
    final id = houseId;
    if (id != null) {
      await FirebaseFirestore.instance.collection('invites').doc(code).set({
        'code': code,
        'houseId': id,
        'email': email,
        'phone': phone,
        'role': role,
        'status': 'sent',
        'createdBy': currentUser?.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return invite;
  }

  /// Fetches invites/{code} to learn its houseId, then joins the current
  /// user to that house: sets users/{uid}.houseId, adds the uid to
  /// houses/{houseId}.members, and marks the invite accepted. Shared by
  /// explicit invite redemption (signup.dart) and the auto-join check below
  /// for accepted marketplace applications.
  Future<void> joinHouseByCode(String code) async {
    final cu = currentUser;
    if (cu == null) return;
    final snap = await FirebaseFirestore.instance.collection('invites').doc(code).get();
    final id = snap.data()?['houseId'] as String?;
    if (id == null) return;
    await FirebaseFirestore.instance.collection('users').doc(cu.id).update({'houseId': id});
    await FirebaseFirestore.instance.collection('houses').doc(id).update({
      'members': FieldValue.arrayUnion([cu.id]),
    });
    await FirebaseFirestore.instance.collection('invites').doc(code).update({'status': 'accepted'});
    mutate(() {
      for (final i in invites) {
        if (i.code == code) i.status = 'accepted';
      }
      currentUser?.houseId = id;
    });
    startHouseSync(id);
  }

  /// If the current user has an accepted marketplace application with an
  /// invite attached, and doesn't have a house yet, join automatically — no
  /// manual "tap to join" needed once a leaseholder accepts their
  /// application. Safe to call repeatedly; a no-op once houseId is set.
  void _maybeAutoJoinFromAcceptedInterest() {
    final cu = currentUser;
    if (cu == null || cu.houseId != null) return;
    final accepted = listingInterests.firstWhereOrNull(
        (i) => i.from == cu.id && i.status == 'accepted' && i.inviteCode != null);
    if (accepted == null) return;
    joinHouseByCode(accepted.inviteCode!).catchError((Object e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Auto-join from accepted interest failed: $e');
      }
    });
  }

  void mutate(void Function() block) {
    block();
    notifyListeners();
    _persist();
  }

  void reset() {
    // Resetting to seed/demo data must never propagate to a live house or
    // community doc.
    stopHouseSync();
    stopGlobalSync();
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
    cleaningAvailability = [];
    choreSwaps = SeedData.choreSwaps();
    rentShares = [];
    rentPayments = SeedData.rentPayments();
    parties = SeedData.parties();
    messages = SeedData.messages();
    complaints = SeedData.complaints();
    issues = SeedData.issues();
    notices = [];
    termination = null;
    listings = SeedData.listings();
    listingInterests = SeedData.listingInterests();
    inspections = SeedData.inspections();
    postMessages = SeedData.postMessages();
    personalExpenses = SeedData.personalExpenses();
    maintenanceContacts = SeedData.maintenanceContacts();
    shoppingList = SeedData.shoppingList();
    welcomeGuide = SeedData.welcomeGuide();
    notifPrefs = NotificationPrefs();
    appNotifications = [];
    houseTerms = HouseTerms();
    notifyListeners();
    _persist();
  }

  void addAppNotification(AppNotification n) {
    mutate(() => appNotifications.insert(0, n));
  }

  void addLhReview(LeaseholderReview r) {
    mutate(() => lhReviews.insert(0, r));
  }

  // Generate contextual in-app notifications from live state (deduped by stable ID).
  void seedContextualNotifs() {
    final uid = session.userId;
    if (uid == null || uid.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existingIds = appNotifications.map((n) => n.id).toSet();
    final toAdd = <AppNotification>[];

    void maybeAdd(AppNotification n) {
      if (!existingIds.contains(n.id)) toAdd.add(n);
    }

    // ── Rent due ──────────────────────────────────────────────────────────────
    final rentStart = property.rentStartDate;
    if (rentStart != null && rentStart.isNotEmpty) {
      var current = rentStart;
      var guard = 0;
      while (guard++ < 5000) {
        final next = addCadence(current, property.rentCadence, null);
        if (next == null) break;
        final nd = parseIso(next);
        if (nd == null) break;
        if (!DateTime(nd.year, nd.month, nd.day).isAfter(today)) {
          current = next;
        } else {
          break;
        }
      }
      final periodDate = parseIso(current);
      if (periodDate != null) {
        final daysAgo = today.difference(DateTime(periodDate.year, periodDate.month, periodDate.day)).inDays;
        if (daysAgo >= 0 && daysAgo <= 5) {
          final alreadyPaid = rentPayments.any((p) => p.userId == uid && p.periodStart == current);
          if (!alreadyPaid) {
            final perPerson = activeHousemates.isEmpty ? property.rentAmount : property.rentAmount / activeHousemates.length;
            maybeAdd(AppNotification(
              id: 'rent_due_${current}_$uid',
              kind: 'rent_due',
              title: daysAgo == 0 ? 'Rent is due today' : 'Rent was due $daysAgo day${daysAgo == 1 ? '' : 's'} ago',
              body: 'Your share is ${fmtAUD(perPerson)} for this period. Mark it paid in Finance.',
              at: parseIso(current)!.toIso8601String(),
              forUserId: uid,
            ));
          }
        }
      }
    }

    // ── Bills due within 4 days ───────────────────────────────────────────────
    for (final b in bills.where((b) => b.status != 'settled' && (b.shares[uid] != null))) {
      if (b.paidBy[uid] == true) continue;
      final due = parseIso(b.dueDate);
      if (due == null) continue;
      final dueDay = DateTime(due.year, due.month, due.day);
      final diff = dueDay.difference(today).inDays;
      if (diff >= -2 && diff <= 4) {
        final label = diff < 0 ? 'overdue ${diff.abs()} day${diff.abs() == 1 ? '' : 's'}' : diff == 0 ? 'due today' : 'due in $diff day${diff == 1 ? '' : 's'}';
        maybeAdd(AppNotification(
          id: 'bill_due_${b.id}_$uid',
          kind: 'bill_due',
          title: 'Bill ${diff < 0 ? 'overdue' : 'due soon'}: ${b.title}',
          body: 'Your share is ${fmtAUD(b.shares[uid]!)} — $label.',
          at: due.toIso8601String(),
          forUserId: uid,
        ));
      }
    }

    // ── Overdue chores ────────────────────────────────────────────────────────
    for (final t in cleaningTasks.where((t) => t.assignee == uid && !t.done && (t.excuse?.isEmpty ?? true))) {
      final due = parseIso(t.dueDate);
      if (due == null) continue;
      final dueDay = DateTime(due.year, due.month, due.day);
      if (dueDay.isBefore(today)) {
        maybeAdd(AppNotification(
          id: 'chore_due_${t.id}_$uid',
          kind: 'chore_due',
          title: 'Overdue chore: ${t.task}',
          body: 'This was due ${fmtRelative(t.dueDate)}. Tick it done or log an excuse in Cleaning.',
          at: due.toIso8601String(),
          forUserId: uid,
        ));
      }
    }

    // ── Pending swap requests ─────────────────────────────────────────────────
    for (final r in choreSwaps.where((r) => r.status == 'pending' && r.fromUserId != uid && (r.toUserId == null || r.toUserId == uid))) {
      final task = cleaningTasks.firstWhereOrNull((t) => t.id == r.taskId);
      maybeAdd(AppNotification(
        id: 'swap_${r.id}_$uid',
        kind: 'swap_request',
        title: '${r.fromUserName} wants to swap a chore',
        body: 'They want to hand off "${task?.task ?? 'a cleaning task'}" — respond in Cleaning.',
        at: r.requestedAt,
        forUserId: uid,
      ));
    }

    if (toAdd.isNotEmpty) {
      mutate(() => appNotifications.insertAll(0, toAdd));
    }
  }

  void markNotificationsRead() {
    mutate(() {
      for (final n in appNotifications) {
        n.isRead = true;
      }
    });
  }

  void clearAppNotifications() {
    mutate(() => appNotifications.clear());
  }

  void signIn(String userId) {
    mutate(() {
      session = Session(userId: userId, pendingSignup: session.pendingSignup);
    });
  }

  /// Credential-free sign-in used by the demo account picker. Ensures the
  /// demo user exists in state (in case persisted data replaced the seed),
  /// then activates their session — no email/password / Firebase required.
  void signInAs(User user) {
    // Demo accounts are always local-only — stop syncing if a real signed-in
    // house/community session was active in this same app session.
    stopHouseSync();
    stopGlobalSync();
    mutate(() {
      if (users.firstWhereOrNull((u) => u.id == user.id) == null) {
        users.add(user);
      }
      session = Session(userId: user.id);
    });
  }

  User? findUser(String? id) {
    if (id == null) return null;
    return users.firstWhereOrNull((u) => u.id == id);
  }

  List<User> get activeHousemates =>
      users.where((u) => !u.pending && (u.moveOutDate == null || u.moveOutDate!.isEmpty)).toList();

  // --- Lease verification (leaseholder submits, admin reviews) --------------

  List<User> get leaseholders => users.where((u) => u.role == 'leaseholder').toList();

  /// Leaseholders awaiting an admin decision on their lease agreement.
  List<User> get pendingLeaseVerifications =>
      leaseholders.where((u) => u.leaseVerification?.status == 'pending').toList();

  /// Called by a leaseholder to submit (or resubmit) their lease for review.
  void submitLeaseVerification(LeaseVerification verification) {
    final cu = currentUser;
    if (cu == null) return;
    mutate(() {
      verification.status = 'pending';
      verification.submittedAt = DateTime.now().toIso8601String();
      verification.reviewedAt = null;
      verification.note = null;
      cu.leaseVerification = verification;
    });
  }

  /// Admin decision: status is 'verified' or 'rejected'. Writes straight to
  /// the leaseholder's `users/{userId}` Firestore doc — an admin reviewing a
  /// real leaseholder's submission isn't a house member of theirs, so there's
  /// no local record of them to mutate the old (house-scoped) way.
  Future<void> reviewLeaseVerification(String userId, String status, {String? note}) async {
    final u = adminAllUsers.firstWhereOrNull((x) => x.id == userId);
    final v = u?.leaseVerification;
    if (v == null) return;
    v.status = status;
    v.note = note;
    v.reviewedAt = DateTime.now().toIso8601String();
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'leaseVerification': v.toJson(),
    });
  }

  // --- Admin: real, platform-wide user management (web-only console) --------

  /// Live query over every real account — only an admin's session can
  /// actually read this (see the `isAdmin()` Firestore rule).
  void startAdminUsersSync() {
    if (_adminUsersSub != null) return;
    _adminUsersSub = FirebaseFirestore.instance.collection('users').snapshots().listen(
      (snap) {
        adminAllUsers = snap.docs.map((d) => User.fromFirestoreDoc(d.id, d.data())).toList();
        notifyListeners();
      },
      onError: (Object e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Admin users sync error: $e');
        }
      },
    );
  }

  void stopAdminUsersSync() {
    _adminUsersSub?.cancel();
    _adminUsersSub = null;
  }

  /// Creates a real Firebase Auth account + `users/{uid}` doc for someone an
  /// admin is adding directly (including granting the admin role itself).
  /// Auth creation runs on a throwaway secondary [FirebaseApp] so it doesn't
  /// sign the calling admin out of their own session (creating a user always
  /// signs the client in as that new user on whatever app instance does it).
  /// The Firestore doc is then written from the *primary* app — i.e. still
  /// authenticated as the admin — so the `isAdmin()` rule branch authorizes
  /// writing a doc whose id isn't the caller's own uid.
  Future<AuthResult> adminCreateUser({
    required String name,
    required String email,
    required String password,
    String phone = '',
    required String role,
  }) async {
    FirebaseApp? secondary;
    try {
      secondary = await Firebase.initializeApp(
        name: 'admin-create-${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final cred = await fb.FirebaseAuth.instanceFor(app: secondary).createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      final displayName = name.trim().isEmpty ? 'New user' : name.trim();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': displayName,
        'initials': _initialsFor(displayName),
        'role': role,
        'email': email.trim(),
        'phone': phone.trim(),
        'pending': role == 'tenant',
        'member': role != 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const AuthResult.success();
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.failure(_authErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Failed to create account: $e');
    } finally {
      await secondary?.delete();
    }
  }

  Future<void> adminSetRole(String id, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(id).update({'role': role});
  }

  /// Fully deletes a user — Auth login and Firestore profile both — via the
  /// small admin-api backend (`backend/admin-api`), since only the Admin SDK
  /// (server-side) can remove another user's Auth login; the client SDK
  /// can't do this directly, no matter how it's signed in.
  Future<AuthResult> adminDeleteUser(String id) async {
    if (id == currentUser?.id) return const AuthResult.failure("Can't delete yourself.");
    final token = await fb.FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return const AuthResult.failure('Not signed in.');
    try {
      final res = await http.delete(
        Uri.parse('$adminApiBaseUrl/users/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) {
        String message = 'Failed to delete (${res.statusCode}).';
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          message = (body['error'] as String?) ?? message;
        } catch (_) {/* non-JSON error body — use the generic message */}
        return AuthResult.failure(message);
      }
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure('Failed to reach admin service: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _houseSub?.cancel();
    _globalSub?.cancel();
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
