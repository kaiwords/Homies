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
import 'sync_reconcile.dart';

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
  List<EssentialListing> essentials = SeedData.essentials();
  List<EssentialBooking> essentialBookings = SeedData.essentialBookings();
  List<GoodsListing> goodsListings = SeedData.goodsListings();
  List<ListingReview> listingReviews = SeedData.listingReviews();

  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _houseSub;
  String? _syncedHouseId;
  bool _applyingRemoteHouse = false;
  // True once the first remote snapshot for the current house has been
  // received and applied (or observed absent). Until then we must NOT push
  // local/seed state up, or a freshly-joined / fresh-device user would clobber
  // the real house doc with local data before ever seeing it.
  bool _houseSnapshotApplied = false;
  // ── Community sync (per-record top-level collections) ───────────────────
  // The marketplace/essentials data used to live in one world-readable/
  // writable community/global document. It's now split into per-record
  // top-level collections, each with its own listener, so the Firestore rules
  // can enforce ownership (public: owner-writes) and participant scoping
  // (private DMs/applications/bookings). See `_globalSpecs()`.
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _globalSubs = [];
  bool _globalSyncing = false;
  bool _applyingRemoteGlobal = false;
  // Per-collection first-snapshot guard: a collection isn't pushed (and its
  // owned remote docs are never deleted) until we've received its first
  // snapshot, so a fresh device never clobbers/deletes remote records it
  // hasn't loaded yet.
  final Map<String, bool> _globalReady = {};
  // Per-collection baseline: docId -> canonical jsonEncode(model.toJson()) of
  // what we believe Firestore currently holds. Rebuilt on each snapshot and
  // updated after each push, so the reconciliation diff only writes/deletes
  // what actually changed.
  final Map<String, Map<String, String>> _globalBaselines = {};

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
    // Essentials, goods, bookings, and reviews — same merge-with-seed
    // treatment as listings/postMessages above, so newly added demo listings/
    // chats/bookings/reviews always show up even on a device with older
    // persisted state.
    final loadedEssentials = ((j['essentials'] as List?) ?? []).map((e) => EssentialListing.fromJson(e as Map<String, dynamic>)).toList();
    final essentialIds = loadedEssentials.map((e) => e.id).toSet();
    essentials = [...loadedEssentials, ...SeedData.essentials().where((e) => !essentialIds.contains(e.id))];
    final loadedBookings = ((j['essentialBookings'] as List?) ?? []).map((e) => EssentialBooking.fromJson(e as Map<String, dynamic>)).toList();
    final bookingIds = loadedBookings.map((b) => b.id).toSet();
    essentialBookings = [...loadedBookings, ...SeedData.essentialBookings().where((b) => !bookingIds.contains(b.id))];
    appNotifications = ((j['appNotifications'] as List?) ?? []).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    final loadedGoods = ((j['goodsListings'] as List?) ?? []).map((e) => GoodsListing.fromJson(e as Map<String, dynamic>)).toList();
    final goodsIds = loadedGoods.map((g) => g.id).toSet();
    goodsListings = [...loadedGoods, ...SeedData.goodsListings().where((g) => !goodsIds.contains(g.id))];
    final loadedReviews = ((j['listingReviews'] as List?) ?? []).map((e) => ListingReview.fromJson(e as Map<String, dynamic>)).toList();
    final reviewIds = loadedReviews.map((r) => r.id).toSet();
    listingReviews = [...loadedReviews, ...SeedData.listingReviews().where((r) => !reviewIds.contains(r.id))];
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
        'listingReviews': listingReviews.map((r) => r.toJson()).toList(),
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
    String? businessName,
  }) async {
    try {
      final cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      final displayName = name.trim().isEmpty ? 'New user' : name.trim();
      final initials = _initialsFor(displayName);
      final trimmedBusinessName = businessName?.trim();
      final hasBusinessName = trimmedBusinessName != null && trimmedBusinessName.isNotEmpty;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': displayName,
        'initials': initials,
        'role': role,
        'email': email.trim(),
        'phone': phone.trim(),
        'pending': true,
        'member': member,
        'createdAt': FieldValue.serverTimestamp(),
        if (hasBusinessName) 'businessName': trimmedBusinessName,
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
            businessName: hasBusinessName ? trimmedBusinessName : null,
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

  /// True when the active session is backed by a real Firebase Auth user
  /// (email/password sign-up), as opposed to a demo / local-only session
  /// created via [signInAs]. Used by the settings UI to decide whether the
  /// delete-account flow needs to re-authenticate with a password.
  bool get hasFirebaseAccount => fb.FirebaseAuth.instance.currentUser != null;

  /// Stops all remote sync, signs out of Firebase, drops the persisted
  /// local-storage blob, and clears the session so the router bounces back to
  /// the welcome/login screen. Deliberately does NOT go through [mutate] — that
  /// would immediately re-persist a fresh seed blob and re-write the key we
  /// just removed.
  Future<void> _clearLocalSessionState() async {
    stopHouseSync();
    stopGlobalSync();
    try {
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {
      // Already signed out (e.g. right after user.delete()) — ignore.
    }
    session = Session();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// User-initiated permanent account deletion (Apple Guideline 5.1.1(v)).
  ///
  /// For a real Firebase account this re-authenticates with [password]
  /// (Firebase requires a recent login before deletion), removes the user from
  /// their house's members array, deletes their `users/{uid}` profile doc,
  /// deletes the Firebase Auth login, then clears all local state. Firestore
  /// work happens BEFORE `user.delete()` because once the Auth user is gone the
  /// client is no longer authorized to write those docs.
  ///
  /// Demo / local-only sessions (no real Firebase user) simply clear local
  /// state and sign out without touching Firebase.
  ///
  /// Errors (wrong password, requires-recent-login, network) are returned as a
  /// failure [AuthResult] with a user-friendly message — this never throws.
  Future<AuthResult> deleteAccount(String password) async {
    final fbUser = fb.FirebaseAuth.instance.currentUser;

    // Demo / local-only session — nothing to delete on the server.
    if (fbUser == null) {
      await _clearLocalSessionState();
      return const AuthResult.success();
    }

    try {
      final email = fbUser.email;
      if (email == null || email.isEmpty) {
        return const AuthResult.failure(
            "This account has no email on file, so it can't be verified for deletion. Please contact support.");
      }

      // Firebase requires a recent login to delete an account — re-authenticate.
      final cred = fb.EmailAuthProvider.credential(email: email, password: password);
      await fbUser.reauthenticateWithCredential(cred);

      final uid = fbUser.uid;
      final hid = houseId;

      // (b) Remove this uid from their house's members array, if any. Best
      // effort — a failure here must not block deleting the account itself.
      if (hid != null) {
        try {
          await FirebaseFirestore.instance.collection('houses').doc(hid).update({
            'members': FieldValue.arrayRemove([uid]),
          });
        } catch (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('deleteAccount: failed to remove from house members: $e');
          }
        }
      }

      // (a) Delete the user's profile doc.
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('deleteAccount: failed to delete user doc: $e');
        }
      }

      // (c) Delete the Firebase Auth login. After this the client is signed out.
      await fbUser.delete();

      // (d) Clear local persisted state and reset the session.
      await _clearLocalSessionState();
      return const AuthResult.success();
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.failure(_authErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Failed to delete account: $e');
    }
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
      case 'requires-recent-login':
        return 'For security, please sign out and sign back in, then try deleting your account again.';
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
    _pushGlobalCollsIfNeeded();
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
    // Do NOT push until we've seen the first remote snapshot for this house —
    // otherwise a freshly-joined / fresh-device user overwrites the real doc
    // with local SEED data before it's ever loaded.
    if (!_houseSnapshotApplied) return;
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
    _houseSnapshotApplied = false; // block pushes until the first snapshot lands
    _houseSub = FirebaseFirestore.instance.collection('houses').doc(id).snapshots().listen(
      (snap) {
        if (snap.metadata.hasPendingWrites) return; // optimistic echo of our own write
        final data = snap.data();
        if (data == null) {
          // Snapshot received, doc absent — this client is free to create it
          // (e.g. the very first write of a brand-new house). Unblock pushes.
          _houseSnapshotApplied = true;
          return;
        }
        _applyingRemoteHouse = true;
        try {
          _applySharedFieldsFromJson(data);
          _houseSnapshotApplied = true;
          notifyListeners();
          _persist();
        } catch (e) {
          // A single malformed doc must not kill the sync — skip and survive.
          if (kDebugMode) {
            // ignore: avoid_print
            print('Skipping malformed house snapshot: $e');
          }
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

  // ── Firestore community sync (per-record top-level collections) ─────────
  // Replaces the old single community/global document. Each marketplace/
  // essentials collection gets its own listener; the Firestore rules enforce
  // ownership on the public ones and participant scoping on the private ones,
  // so a listen has to be provably within the rules — hence the private
  // collections are queried with `where('participants', arrayContains: uid)`
  // (rules are NOT filters: an unconstrained listen would be denied).
  //
  // These client changes MUST be deployed together with
  // backend/database/firestore.rules.proposed — the old single-doc client
  // breaks under the new rules and the new client breaks under the old rules.

  /// Describes one synced collection: how to query it (scoped to this user
  /// where required), how to serialize the in-memory list, how to apply a
  /// remote snapshot back into memory, and who is allowed to write/delete a
  /// given doc.
  List<_GlobalColl> _globalSpecs() {
    final uid = session.userId ?? '';
    final fs = FirebaseFirestore.instance;
    bool ownsBy(String field, Map<String, dynamic> j) => (j[field] ?? '') == uid && uid.isNotEmpty;
    bool participant(List<String> fields, Map<String, dynamic> j) =>
        uid.isNotEmpty && fields.any((f) => (j[f] ?? '') == uid);

    return [
      // ── Public: read by all, write by owner ──
      _GlobalColl(
        name: 'listings',
        query: () => fs.collection('listings'),
        current: () => listings.map((l) => l.toJson()).toList(),
        apply: (datas) => listings = _parseDocs(datas, Listing.fromJson, 'listings'),
        canWrite: (j) => ownsBy('by', j),
        canDelete: (j) => ownsBy('by', j),
      ),
      _GlobalColl(
        name: 'goodsListings',
        query: () => fs.collection('goodsListings'),
        current: () => goodsListings.map((g) => g.toJson()).toList(),
        apply: (datas) => goodsListings = _parseDocs(datas, GoodsListing.fromJson, 'goodsListings'),
        canWrite: (j) => ownsBy('postedBy', j),
        canDelete: (j) => ownsBy('postedBy', j),
      ),
      _GlobalColl(
        name: 'essentials',
        query: () => fs.collection('essentials'),
        current: () => essentials.map((e) => e.toJson()).toList(),
        apply: (datas) => essentials = _parseDocs(datas, EssentialListing.fromJson, 'essentials'),
        canWrite: (j) => ownsBy('postedBy', j),
        canDelete: (j) => ownsBy('postedBy', j),
      ),
      _GlobalColl(
        name: 'listingReviews',
        query: () => fs.collection('listingReviews'),
        current: () => listingReviews.map((r) => r.toJson()).toList(),
        apply: (datas) => listingReviews = _parseDocs(datas, ListingReview.fromJson, 'listingReviews'),
        canWrite: (j) => ownsBy('fromUserId', j),
        canDelete: (j) => ownsBy('fromUserId', j),
      ),
      // ── Private: participant-scoped (queried with array-contains) ──
      _GlobalColl(
        name: 'listingInterests',
        query: () => fs.collection('listingInterests').where('participants', arrayContains: uid),
        current: () => listingInterests.map((i) => i.toJson()).toList(),
        apply: (datas) => listingInterests = _parseDocs(datas, ListingInterest.fromJson, 'listingInterests'),
        canWrite: (j) => participant(['from', 'to'], j),
        canDelete: (j) => participant(['from', 'to'], j),
      ),
      _GlobalColl(
        name: 'postMessages',
        query: () => fs.collection('postMessages').where('participants', arrayContains: uid),
        current: () => postMessages.map((m) => m.toJson()).toList(),
        apply: (datas) => postMessages = _parseDocs(datas, PostMessage.fromJson, 'postMessages'),
        canWrite: (j) => participant(['from', 'to'], j),
        canDelete: (j) => participant(['from', 'to'], j),
        // Rules forbid deleting DMs (allow delete: if false) — never issue one.
        allowDelete: false,
      ),
      _GlobalColl(
        name: 'inspections',
        query: () => fs.collection('inspections').where('participants', arrayContains: uid),
        current: () => inspections.map((i) => i.toJson()).toList(),
        apply: (datas) => inspections = _parseDocs(datas, Inspection.fromJson, 'inspections'),
        canWrite: (j) => participant(['requestedBy', 'to'], j),
        canDelete: (j) => participant(['requestedBy', 'to'], j),
      ),
      _GlobalColl(
        name: 'essentialBookings',
        query: () => fs.collection('essentialBookings').where('participants', arrayContains: uid),
        current: () => essentialBookings.map((b) => b.toJson()).toList(),
        apply: (datas) => essentialBookings = _parseDocs(datas, EssentialBooking.fromJson, 'essentialBookings'),
        canWrite: (j) => participant(['requestedBy', 'businessOwnerId'], j),
        canDelete: (j) => participant(['requestedBy', 'businessOwnerId'], j),
        // Rules forbid deleting bookings (allow delete: if false).
        allowDelete: false,
      ),
      // ── Notifications: recipient-scoped read; anyone may create (we create
      // notifications addressed to OTHER users), but only the recipient deletes.
      _GlobalColl(
        name: 'appNotifications',
        query: () => fs.collection('appNotifications').where('forUserId', isEqualTo: uid),
        current: () => appNotifications.map((n) => n.toJson()).toList(),
        apply: (datas) => appNotifications = _parseDocs(datas, AppNotification.fromJson, 'appNotifications'),
        canWrite: (j) => uid.isNotEmpty, // create allowed for any signed-in user
        canDelete: (j) => ownsBy('forUserId', j),
      ),
    ];
  }

  /// Parses a batch of Firestore doc datas via [fromJson], skipping (and
  /// logging) any single malformed doc so one bad record can't kill sync —
  /// mirrors the house-sync resilience.
  List<T> _parseDocs<T>(
    List<Map<String, dynamic>> datas,
    T Function(Map<String, dynamic>) fromJson,
    String label,
  ) {
    final out = <T>[];
    for (final d in datas) {
      try {
        out.add(fromJson(d));
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Skipping malformed $label doc: $e');
        }
      }
    }
    return out;
  }

  Map<String, String> _baselineFrom(List<Map<String, dynamic>> jsons) {
    final m = <String, String>{};
    for (final j in jsons) {
      final id = (j['id'] ?? '') as String;
      if (id.isEmpty) continue;
      m[id] = jsonEncode(j);
    }
    return m;
  }

  /// Per-collection reconciliation, replacing the old single-doc push. For
  /// each collection, diff the in-memory list against our baseline and write
  /// the added/changed docs THIS USER MAY WRITE and delete the owned docs
  /// removed locally. Never touches other users' records (received via the
  /// listeners) — the rules would reject those writes anyway.
  void _pushGlobalCollsIfNeeded() {
    // Skip while applying a remote snapshot (this write would just echo it),
    // and when community sync isn't active (demo/local session) — same intent
    // as the old gate on _globalSyncing.
    if (_applyingRemoteGlobal || !_globalSyncing) return;
    final uid = session.userId;
    if (uid == null || uid.isEmpty) return;
    final fs = FirebaseFirestore.instance;
    for (final c in _globalSpecs()) {
      // Readiness gate: don't push (or delete) until this collection's first
      // snapshot has landed, so we never delete remote docs before loading them.
      if (_globalReady[c.name] != true) continue;
      final baseline = _globalBaselines[c.name] ?? const <String, String>{};
      final diff = reconcileCollection(
        baseline: baseline,
        current: c.current(),
        canWrite: c.canWrite,
        canDelete: c.canDelete,
      );
      if (diff.toWrite.isEmpty && diff.toDelete.isEmpty) continue;
      final coll = fs.collection(c.name);
      final next = Map<String, String>.from(baseline);
      diff.toWrite.forEach((id, json) {
        coll.doc(id).set(json).catchError((Object e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('Failed to push ${c.name}/$id: $e');
          }
        });
        next[id] = jsonEncode(json);
      });
      if (c.allowDelete) {
        for (final id in diff.toDelete) {
          coll.doc(id).delete().catchError((Object e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('Failed to delete ${c.name}/$id: $e');
            }
          });
          next.remove(id);
        }
      }
      _globalBaselines[c.name] = next;
    }
  }

  /// Starts one listener per community collection. Safe to call repeatedly —
  /// a no-op if already syncing. Requires a signed-in uid (private queries are
  /// scoped to it); demo/local sessions never call this.
  void startGlobalSync() {
    if (_globalSyncing && _globalSubs.isNotEmpty) return;
    final uid = session.userId;
    if (uid == null || uid.isEmpty) return;
    stopGlobalSync(); // cancel any stragglers, reset flags/baselines
    _globalSyncing = true;
    for (final c in _globalSpecs()) {
      final sub = c.query().snapshots().listen(
        (snap) {
          _applyingRemoteGlobal = true;
          try {
            final datas = snap.docs.map((d) => d.data()).toList();
            c.apply(datas); // replace the in-memory list; remote is authoritative
            // Rebuild the baseline from the freshly-applied list so it's in the
            // exact same canonical form the reconciliation diff compares against.
            _globalBaselines[c.name] = _baselineFrom(c.current());
            _globalReady[c.name] = true;
            notifyListeners();
            _persist();
            if (c.name == 'listingInterests') _maybeAutoJoinFromAcceptedInterest();
          } catch (e) {
            // A single bad snapshot must not kill sync — skip and survive.
            if (kDebugMode) {
              // ignore: avoid_print
              print('Skipping malformed ${c.name} snapshot: $e');
            }
          } finally {
            _applyingRemoteGlobal = false;
          }
        },
        onError: (Object e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('${c.name} sync error: $e');
          }
        },
      );
      _globalSubs.add(sub);
    }
  }

  void stopGlobalSync() {
    for (final s in _globalSubs) {
      s.cancel();
    }
    _globalSubs.clear();
    _globalSyncing = false;
    _applyingRemoteGlobal = false;
    _globalReady.clear();
    _globalBaselines.clear();
  }

  void stopHouseSync() {
    _houseSub?.cancel();
    _houseSub = null;
    _syncedHouseId = null;
    _houseSnapshotApplied = false;
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
  Future<Invite> createInvite({String? email, String? phone, String method = 'email', required String role}) async {
    final code = 'HMI-${Random().nextInt(0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final invite = Invite(code: code, email: email, phone: phone, method: method, role: role, sentAt: todayIso());
    mutate(() => invites.add(invite));
    final id = houseId;
    if (id != null) {
      await FirebaseFirestore.instance.collection('invites').doc(code).set({
        'code': code,
        'houseId': id,
        'email': email,
        'phone': phone,
        'method': method,
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
    _adminUsersSub?.cancel();
    for (final s in _globalSubs) {
      s.cancel();
    }
    _globalSubs.clear();
    super.dispose();
  }
}

/// Configuration for one synced community collection — how to query, serialize,
/// apply, and authorize writes/deletes. Built per-user by [HomiesState._globalSpecs].
class _GlobalColl {
  final String name;
  final Query<Map<String, dynamic>> Function() query;
  final List<Map<String, dynamic>> Function() current;
  final void Function(List<Map<String, dynamic>> datas) apply;
  final bool Function(Map<String, dynamic> json) canWrite;
  final bool Function(Map<String, dynamic> json) canDelete;
  final bool allowDelete;

  _GlobalColl({
    required this.name,
    required this.query,
    required this.current,
    required this.apply,
    required this.canWrite,
    required this.canDelete,
    this.allowDelete = true,
  });
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
