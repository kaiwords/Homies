// All entities are simple mutable classes; we serialise to JSON for
// shared_preferences persistence. Mirrors the React mockData shape.

class Attachment {
  String? fileName;
  // Legacy inline payload: a `data:<mime>;base64,...` URL. Kept for backward
  // compatibility — pre-Phase-3 attachments (and demo/offline captures with no
  // signed-in Firebase user) still store their bytes here.
  String? dataUrl;
  // Phase 3: a Firebase Storage download URL. When set, the bytes live in
  // Storage (not in the synced doc) and [dataUrl] is left null so synced
  // Firestore docs stay tiny.
  String? url;
  // The Storage object path (`media/{uid}/{uuid}.{ext}`) backing [url], kept so
  // the object can be deleted later.
  String? storagePath;
  String? type;
  int? size;
  String? uploadedAt;
  // Duration in milliseconds, for audio/video attachments (voice notes, clips).
  int? durationMs;

  Attachment({
    this.fileName,
    this.dataUrl,
    this.url,
    this.storagePath,
    this.type,
    this.size,
    this.uploadedAt,
    this.durationMs,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'dataUrl': dataUrl,
        'url': url,
        'storagePath': storagePath,
        'type': type,
        'size': size,
        'uploadedAt': uploadedAt,
        'durationMs': durationMs,
      };

  static Attachment? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return Attachment(
      fileName: j['fileName'] as String?,
      dataUrl: j['dataUrl'] as String?,
      url: j['url'] as String?,
      storagePath: j['storagePath'] as String?,
      type: j['type'] as String?,
      size: (j['size'] as num?)?.toInt(),
      uploadedAt: j['uploadedAt'] as String?,
      durationMs: (j['durationMs'] as num?)?.toInt(),
    );
  }
}

class IdDocSubmission {
  String? kind;
  String? fileName;
  String? dataUrl; // legacy inline base64 (backward compat)
  String? url; // Firebase Storage download URL (preferred)
  String? storagePath;
  String? type;
  int? size;
  String? uploadedAt;

  IdDocSubmission({this.kind, this.fileName, this.dataUrl, this.url, this.storagePath, this.type, this.size, this.uploadedAt});

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'fileName': fileName,
        'dataUrl': dataUrl,
        'url': url,
        'storagePath': storagePath,
        'type': type,
        'size': size,
        'uploadedAt': uploadedAt,
      };

  static IdDocSubmission? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return IdDocSubmission(
      kind: j['kind'] as String?,
      fileName: j['fileName'] as String?,
      dataUrl: j['dataUrl'] as String?,
      url: j['url'] as String?,
      storagePath: j['storagePath'] as String?,
      type: j['type'] as String?,
      size: (j['size'] as num?)?.toInt(),
      uploadedAt: j['uploadedAt'] as String?,
    );
  }
}

class PaymentSubmission {
  String? method;
  String? fileName;
  String? dataUrl; // legacy inline base64 (backward compat)
  String? url; // Firebase Storage download URL (preferred)
  String? storagePath;
  String? type;
  int? size;
  String? uploadedAt;

  PaymentSubmission({this.method, this.fileName, this.dataUrl, this.url, this.storagePath, this.type, this.size, this.uploadedAt});

  Map<String, dynamic> toJson() => {
        'method': method,
        'fileName': fileName,
        'dataUrl': dataUrl,
        'url': url,
        'storagePath': storagePath,
        'type': type,
        'size': size,
        'uploadedAt': uploadedAt,
      };

  static PaymentSubmission? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return PaymentSubmission(
      method: j['method'] as String?,
      fileName: j['fileName'] as String?,
      dataUrl: j['dataUrl'] as String?,
      url: j['url'] as String?,
      storagePath: j['storagePath'] as String?,
      type: j['type'] as String?,
      size: (j['size'] as num?)?.toInt(),
      uploadedAt: j['uploadedAt'] as String?,
    );
  }
}

class Submissions {
  IdDocSubmission? idDoc;
  PaymentSubmission? bondProof;
  PaymentSubmission? advanceRentProof;

  Submissions({this.idDoc, this.bondProof, this.advanceRentProof});

  Map<String, dynamic> toJson() => {
        'idDoc': idDoc?.toJson(),
        'bondProof': bondProof?.toJson(),
        'advanceRentProof': advanceRentProof?.toJson(),
      };

  static Submissions? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return Submissions(
      idDoc: IdDocSubmission.fromJson(j['idDoc'] as Map<String, dynamic>?),
      bondProof: PaymentSubmission.fromJson(j['bondProof'] as Map<String, dynamic>?),
      advanceRentProof: PaymentSubmission.fromJson(j['advanceRentProof'] as Map<String, dynamic>?),
    );
  }
}

/// Lifestyle / compatibility answers every user fills in. Empty string means
/// "not answered yet". Used for housemate matching and shown to a leaseholder
/// when someone applies to a room.
class Lifestyle {
  String smoking; // non-smoker | outside-only | smoker
  String alcohol; // none | social | regular
  String drugs; // no | occasionally | regularly
  String relationship; // single | relationship | married
  String pets; // none | has-pets
  String diet; // none | vegetarian | vegan | halal | other
  String occupation; // free text
  String schedule; // early-bird | flexible | night-owl
  String guests; // rarely | sometimes | often
  String cleanliness; // very-tidy | tidy | average | messy
  String about; // free-text intro

  Lifestyle({
    this.smoking = '',
    this.alcohol = '',
    this.drugs = '',
    this.relationship = '',
    this.pets = '',
    this.diet = '',
    this.occupation = '',
    this.schedule = '',
    this.guests = '',
    this.cleanliness = '',
    this.about = '',
  });

  /// The core questions we require everyone to answer.
  bool get isComplete =>
      smoking.isNotEmpty && alcohol.isNotEmpty && relationship.isNotEmpty && pets.isNotEmpty && schedule.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'smoking': smoking,
        'alcohol': alcohol,
        'drugs': drugs,
        'relationship': relationship,
        'pets': pets,
        'diet': diet,
        'occupation': occupation,
        'schedule': schedule,
        'guests': guests,
        'cleanliness': cleanliness,
        'about': about,
      };

  static Lifestyle? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return Lifestyle(
      smoking: (j['smoking'] ?? '') as String,
      alcohol: (j['alcohol'] ?? '') as String,
      drugs: (j['drugs'] ?? '') as String,
      relationship: (j['relationship'] ?? '') as String,
      pets: (j['pets'] ?? '') as String,
      diet: (j['diet'] ?? '') as String,
      occupation: (j['occupation'] ?? '') as String,
      schedule: (j['schedule'] ?? '') as String,
      guests: (j['guests'] ?? '') as String,
      cleanliness: (j['cleanliness'] ?? '') as String,
      about: (j['about'] ?? '') as String,
    );
  }

  Lifestyle copy() => Lifestyle.fromJson(toJson())!;
}

class EmergencyContact {
  String name;
  String relationship;
  String phone;

  EmergencyContact({this.name = '', this.relationship = '', this.phone = ''});

  bool get isComplete => name.isNotEmpty && phone.isNotEmpty;

  Map<String, dynamic> toJson() => {'name': name, 'relationship': relationship, 'phone': phone};

  static EmergencyContact? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return EmergencyContact(
      name: (j['name'] ?? '') as String,
      relationship: (j['relationship'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
    );
  }

  EmergencyContact copy() => EmergencyContact.fromJson(toJson())!;
}

/// A leaseholder's submission for platform-admin verification: the lease
/// agreement plus the contact details on it. Reviewed by an admin.
class LeaseVerification {
  Attachment? agreement; // the uploaded lease document
  String fullName; // name as it appears on the lease
  String phone;
  String email;
  String status; // 'pending' | 'verified' | 'rejected'
  String? note; // admin note / reason for rejection
  String? submittedAt;
  String? reviewedAt;

  LeaseVerification({
    this.agreement,
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.status = 'pending',
    this.note,
    this.submittedAt,
    this.reviewedAt,
  });

  bool get isComplete => (agreement != null) && fullName.isNotEmpty && phone.isNotEmpty && email.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'agreement': agreement?.toJson(),
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'status': status,
        'note': note,
        'submittedAt': submittedAt,
        'reviewedAt': reviewedAt,
      };

  static LeaseVerification? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return LeaseVerification(
      agreement: Attachment.fromJson(j['agreement'] as Map<String, dynamic>?),
      fullName: (j['fullName'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      status: (j['status'] ?? 'pending') as String,
      note: j['note'] as String?,
      submittedAt: j['submittedAt'] as String?,
      reviewedAt: j['reviewedAt'] as String?,
    );
  }

  LeaseVerification copy() => LeaseVerification.fromJson(toJson())!;
}

class User {
  String id;
  String name;
  String initials;
  String role; // 'admin' | 'leaseholder' | 'tenant' | 'business'
  String email;
  String phone;
  String? moveInDate;
  String? moveOutDate;
  bool bondPaid;
  double bondAmount;
  bool docVerified;
  bool advanceRentPaid;
  String? acceptedRulesAt;
  String? acceptedTermsAt;
  bool pending;
  // Whether this person belongs to the house (leaseholder, or a tenant who
  // accepted a leaseholder's invite). Non-members can only browse the
  // marketplace until they're invited in.
  bool member;
  Lifestyle? lifestyle;
  EmergencyContact? emergency;
  // Whether housemates may see this person's emergency contact. The leaseholder
  // can always see everyone's; this only governs tenant-to-tenant visibility.
  // Defaults to private — the owner opts in to sharing.
  bool shareEmergency;
  bool sharePhone;
  bool shareEmail;
  bool shareLifestyle;
  Submissions? submissions;
  // Leaseholder-only: their lease agreement submission for admin verification.
  LeaseVerification? leaseVerification;
  // Tenant-only: reference to their current/previous leaseholder on Homies.
  String? leaseholderUserId; // Homies user ID of the leaseholder
  String? leaseholderName;   // display name (shown when user not on platform)
  // The house this user belongs to, once they've created or joined one via
  // Firestore sync. Null for browsers, demo accounts, and pre-onboarding
  // leaseholders.
  String? houseId;
  // Business-only: their seller display name, shown on Essentials/Marketplace
  // listings. Null for every other role.
  String? businessName;

  User({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
    required this.email,
    required this.phone,
    this.moveInDate,
    this.moveOutDate,
    this.bondPaid = false,
    this.bondAmount = 0,
    this.docVerified = false,
    this.advanceRentPaid = false,
    this.acceptedRulesAt,
    this.acceptedTermsAt,
    this.pending = false,
    this.member = true,
    this.lifestyle,
    this.emergency,
    this.shareEmergency = false,
    this.sharePhone = true,
    this.shareEmail = true,
    this.shareLifestyle = true,
    this.submissions,
    this.leaseVerification,
    this.leaseholderUserId,
    this.leaseholderName,
    this.houseId,
    this.businessName,
  });

  bool get isAdmin => role == 'admin';
  bool get isLeaseholder => role == 'leaseholder';
  bool get isBusiness => role == 'business';
  String get leaseStatus => leaseVerification?.status ?? 'none';

  /// Everyone must answer the lifestyle questions and add an emergency contact.
  bool get profileComplete => (lifestyle?.isComplete ?? false) && (emergency?.isComplete ?? false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'role': role,
        'email': email,
        'phone': phone,
        'moveInDate': moveInDate,
        'moveOutDate': moveOutDate,
        'bondPaid': bondPaid,
        'bondAmount': bondAmount,
        'docVerified': docVerified,
        'advanceRentPaid': advanceRentPaid,
        'acceptedRulesAt': acceptedRulesAt,
        'acceptedTermsAt': acceptedTermsAt,
        'pending': pending,
        'member': member,
        'lifestyle': lifestyle?.toJson(),
        'emergency': emergency?.toJson(),
        'shareEmergency': shareEmergency,
        'sharePhone': sharePhone,
        'shareEmail': shareEmail,
        'shareLifestyle': shareLifestyle,
        'submissions': submissions?.toJson(),
        'leaseVerification': leaseVerification?.toJson(),
        'leaseholderUserId': leaseholderUserId,
        'leaseholderName': leaseholderName,
        'houseId': houseId,
        'businessName': businessName,
      };

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        initials: (j['initials'] ?? '') as String,
        role: (j['role'] ?? 'tenant') as String,
        email: (j['email'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        moveInDate: j['moveInDate'] as String?,
        moveOutDate: j['moveOutDate'] as String?,
        bondPaid: (j['bondPaid'] ?? false) as bool,
        bondAmount: ((j['bondAmount'] ?? 0) as num).toDouble(),
        docVerified: (j['docVerified'] ?? false) as bool,
        advanceRentPaid: (j['advanceRentPaid'] ?? false) as bool,
        acceptedRulesAt: j['acceptedRulesAt'] as String?,
        acceptedTermsAt: j['acceptedTermsAt'] as String?,
        pending: (j['pending'] ?? false) as bool,
        member: (j['member'] ?? true) as bool,
        lifestyle: Lifestyle.fromJson(j['lifestyle'] as Map<String, dynamic>?),
        emergency: EmergencyContact.fromJson(j['emergency'] as Map<String, dynamic>?),
        shareEmergency: (j['shareEmergency'] ?? false) as bool,
        sharePhone: (j['sharePhone'] ?? true) as bool,
        shareEmail: (j['shareEmail'] ?? true) as bool,
        shareLifestyle: (j['shareLifestyle'] ?? true) as bool,
        submissions: Submissions.fromJson(j['submissions'] as Map<String, dynamic>?),
        leaseVerification: LeaseVerification.fromJson(j['leaseVerification'] as Map<String, dynamic>?),
        leaseholderUserId: j['leaseholderUserId'] as String?,
        leaseholderName: j['leaseholderName'] as String?,
        houseId: j['houseId'] as String?,
        businessName: j['businessName'] as String?,
      );

  /// Builds a User from a `users/{uid}` Firestore doc, where the id lives in
  /// the doc's key rather than as a field — unlike [fromJson], every field
  /// falls back to a safe default instead of throwing, since a Firestore doc
  /// may be missing fields an older/partial write didn't set.
  factory User.fromFirestoreDoc(String id, Map<String, dynamic> data) => User(
        id: id,
        name: (data['name'] as String?) ?? '',
        initials: (data['initials'] as String?) ?? _initialsFor((data['name'] as String?) ?? ''),
        role: (data['role'] as String?) ?? 'tenant',
        email: (data['email'] as String?) ?? '',
        phone: (data['phone'] as String?) ?? '',
        moveInDate: data['moveInDate'] as String?,
        moveOutDate: data['moveOutDate'] as String?,
        bondPaid: (data['bondPaid'] as bool?) ?? false,
        bondAmount: ((data['bondAmount'] as num?) ?? 0).toDouble(),
        docVerified: (data['docVerified'] as bool?) ?? false,
        advanceRentPaid: (data['advanceRentPaid'] as bool?) ?? false,
        acceptedRulesAt: data['acceptedRulesAt'] as String?,
        pending: (data['pending'] as bool?) ?? true,
        member: (data['member'] as bool?) ?? true,
        shareEmergency: (data['shareEmergency'] as bool?) ?? false,
        houseId: data['houseId'] as String?,
        leaseVerification: LeaseVerification.fromJson(data['leaseVerification'] as Map<String, dynamic>?),
        businessName: data['businessName'] as String?,
      );
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '??';
  return parts.take(2).map((p) => p[0]).join().toUpperCase();
}

class Property {
  String id;
  String address;
  String type;
  int bedrooms;
  int bathrooms;
  Map<String, bool> features;
  String agent;
  String agentContact;
  String? leaseStart;
  String? leaseEnd;
  double rentAmount;
  String rentCadence;
  String? rentStartDate;
  int bondWeeks;
  int advanceWeeks;
  int maxOccupants;
  bool setupComplete;
  String cleaningCadence; // 'weekly' | 'fortnightly' | 'monthly'
  bool cleaningAvailabilityRequested;
  String? leaseNotificationSentAt;
  String? rentShareExplanation;

  Property({
    required this.id,
    required this.address,
    this.type = 'House',
    this.bedrooms = 1,
    this.bathrooms = 1,
    Map<String, bool>? features,
    this.agent = '',
    this.agentContact = '',
    this.leaseStart,
    this.leaseEnd,
    this.rentAmount = 0,
    this.rentCadence = 'weekly',
    this.rentStartDate,
    this.bondWeeks = 4,
    this.advanceWeeks = 2,
    this.maxOccupants = 4,
    this.setupComplete = false,
    this.cleaningCadence = 'weekly',
    this.cleaningAvailabilityRequested = false,
    this.leaseNotificationSentAt,
    this.rentShareExplanation,
  }) : features = features ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'address': address,
        'type': type,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'features': features,
        'agent': agent,
        'agentContact': agentContact,
        'leaseStart': leaseStart,
        'leaseEnd': leaseEnd,
        'rentAmount': rentAmount,
        'rentCadence': rentCadence,
        'rentStartDate': rentStartDate,
        'bondWeeks': bondWeeks,
        'advanceWeeks': advanceWeeks,
        'maxOccupants': maxOccupants,
        'setupComplete': setupComplete,
        'cleaningCadence': cleaningCadence,
        'cleaningAvailabilityRequested': cleaningAvailabilityRequested,
        'leaseNotificationSentAt': leaseNotificationSentAt,
        'rentShareExplanation': rentShareExplanation,
      };

  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: (j['id'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        type: (j['type'] ?? 'House') as String,
        bedrooms: ((j['bedrooms'] ?? 1) as num).toInt(),
        bathrooms: ((j['bathrooms'] ?? 1) as num).toInt(),
        features: ((j['features'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v as bool)),
        agent: (j['agent'] ?? '') as String,
        agentContact: (j['agentContact'] ?? '') as String,
        leaseStart: j['leaseStart'] as String?,
        leaseEnd: j['leaseEnd'] as String?,
        rentAmount: ((j['rentAmount'] ?? 0) as num).toDouble(),
        rentCadence: (j['rentCadence'] ?? 'weekly') as String,
        rentStartDate: j['rentStartDate'] as String?,
        bondWeeks: ((j['bondWeeks'] ?? 4) as num).toInt(),
        advanceWeeks: ((j['advanceWeeks'] ?? 2) as num).toInt(),
        maxOccupants: ((j['maxOccupants'] ?? 4) as num).toInt(),
        setupComplete: (j['setupComplete'] ?? false) as bool,
        cleaningCadence: (j['cleaningCadence'] ?? 'weekly') as String,
        cleaningAvailabilityRequested: (j['cleaningAvailabilityRequested'] ?? false) as bool,
        leaseNotificationSentAt: j['leaseNotificationSentAt'] as String?,
        rentShareExplanation: j['rentShareExplanation'] as String?,
      );
}

/// How the leaseholder chose to reach the invitee — determines which single
/// contact field was collected and which "send" action is offered once the
/// code is generated.
class Invite {
  String code;
  String? email;
  String? phone;
  String method; // 'email' | 'phone' | 'social'
  String role;
  String sentAt;
  String status;

  Invite({
    required this.code,
    this.email,
    this.phone,
    this.method = 'email',
    required this.role,
    required this.sentAt,
    this.status = 'sent',
  });

  Map<String, dynamic> toJson() =>
      {'code': code, 'email': email, 'phone': phone, 'method': method, 'role': role, 'sentAt': sentAt, 'status': status};
  factory Invite.fromJson(Map<String, dynamic> j) => Invite(
        code: (j['code'] ?? '') as String,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        // Older invites predate the `method` field — infer it from whichever
        // contact field they happen to have.
        method: (j['method'] as String?) ??
            (((j['email'] as String?)?.isNotEmpty ?? false)
                ? 'email'
                : (((j['phone'] as String?)?.isNotEmpty ?? false) ? 'phone' : 'social')),
        role: (j['role'] ?? '') as String,
        sentAt: (j['sentAt'] ?? '') as String,
        status: (j['status'] ?? 'sent') as String,
      );
}

class HouseRule {
  String id;
  String text;
  String addedBy;
  String addedAt;
  HouseRule({required this.id, required this.text, required this.addedBy, required this.addedAt});
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'addedBy': addedBy, 'addedAt': addedAt};
  factory HouseRule.fromJson(Map<String, dynamic> j) => HouseRule(
        id: (j['id'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        addedBy: (j['addedBy'] ?? '') as String,
        addedAt: (j['addedAt'] ?? '') as String,
      );
}

/// A saved, point-in-time record that a person's share of a bill was paid.
/// Kept by name + timestamp so there's no later misunderstanding about who
/// paid what and when.
class Payment {
  String payerId;
  String payerName;
  String? confirmedBy; // name of who marked it paid, if different from the payer
  String at; // ISO timestamp
  double amount;

  Payment({
    required this.payerId,
    required this.payerName,
    this.confirmedBy,
    required this.at,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'payerId': payerId,
        'payerName': payerName,
        'confirmedBy': confirmedBy,
        'at': at,
        'amount': amount,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        payerId: (j['payerId'] ?? '') as String,
        payerName: (j['payerName'] ?? '') as String,
        confirmedBy: j['confirmedBy'] as String?,
        at: (j['at'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
      );
}

class Bill {
  String id;
  String title;
  String category;
  double amount;
  String? periodStart;
  String? periodEnd;
  String dueDate;
  String issuedBy;
  String split;
  Map<String, double> shares;
  String status;
  Map<String, bool> paidBy;
  Map<String, Payment> payments; // saved payment records, keyed by payerId
  String? scheduleId;
  Attachment? proof;
  Attachment? receipt;

  Bill({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    this.periodStart,
    this.periodEnd,
    required this.dueDate,
    required this.issuedBy,
    required this.split,
    required this.shares,
    this.status = 'pending',
    Map<String, bool>? paidBy,
    Map<String, Payment>? payments,
    this.scheduleId,
    this.proof,
    this.receipt,
  })  : paidBy = paidBy ?? {},
        payments = payments ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
        'dueDate': dueDate,
        'issuedBy': issuedBy,
        'split': split,
        'shares': shares,
        'status': status,
        'paidBy': paidBy,
        'payments': payments.map((k, v) => MapEntry(k, v.toJson())),
        'scheduleId': scheduleId,
        'proof': proof?.toJson(),
        'receipt': receipt?.toJson(),
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        category: (j['category'] ?? 'other') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        periodStart: j['periodStart'] as String?,
        periodEnd: j['periodEnd'] as String?,
        dueDate: (j['dueDate'] ?? '') as String,
        issuedBy: (j['issuedBy'] ?? '') as String,
        split: (j['split'] ?? 'equal') as String,
        shares: ((j['shares'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        status: (j['status'] ?? 'pending') as String,
        paidBy: ((j['paidBy'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v as bool)),
        payments: ((j['payments'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), Payment.fromJson(v as Map<String, dynamic>))),
        scheduleId: j['scheduleId'] as String?,
        proof: Attachment.fromJson(j['proof'] as Map<String, dynamic>?),
        receipt: Attachment.fromJson(j['receipt'] as Map<String, dynamic>?),
      );
}

class BillSchedule {
  String id;
  String title;
  String category;
  String cadence;
  int? customDays;
  String cycleStart;
  String nextDueDate;
  double estimatedAmount;
  String splitMethod;
  List<String> participants;
  bool active;
  String createdBy;

  BillSchedule({
    required this.id,
    required this.title,
    required this.category,
    required this.cadence,
    this.customDays,
    required this.cycleStart,
    required this.nextDueDate,
    this.estimatedAmount = 0,
    this.splitMethod = 'equal',
    required this.participants,
    this.active = true,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'cadence': cadence,
        'customDays': customDays,
        'cycleStart': cycleStart,
        'nextDueDate': nextDueDate,
        'estimatedAmount': estimatedAmount,
        'splitMethod': splitMethod,
        'participants': participants,
        'active': active,
        'createdBy': createdBy,
      };

  factory BillSchedule.fromJson(Map<String, dynamic> j) => BillSchedule(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        category: (j['category'] ?? 'other') as String,
        cadence: (j['cadence'] ?? 'monthly') as String,
        customDays: (j['customDays'] as num?)?.toInt(),
        cycleStart: (j['cycleStart'] ?? '') as String,
        nextDueDate: (j['nextDueDate'] ?? '') as String,
        estimatedAmount: ((j['estimatedAmount'] ?? 0) as num).toDouble(),
        splitMethod: (j['splitMethod'] ?? 'equal') as String,
        participants: ((j['participants'] as List?) ?? []).map((e) => e.toString()).toList(),
        active: (j['active'] ?? true) as bool,
        createdBy: (j['createdBy'] ?? '') as String,
      );
}

class Subscription {
  String id;
  String name;
  double amount;
  String cadence;
  String payer;
  List<String> participants;
  String split;
  Map<String, double> shares;
  Map<String, bool> paidBy;
  Map<String, Payment> payments;
  Attachment? receipt;

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.cadence,
    required this.payer,
    required this.participants,
    this.split = 'equal',
    required this.shares,
    Map<String, bool>? paidBy,
    Map<String, Payment>? payments,
    this.receipt,
  })  : paidBy = paidBy ?? {},
        payments = payments ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'cadence': cadence,
        'payer': payer,
        'participants': participants,
        'split': split,
        'shares': shares,
        'paidBy': paidBy,
        'payments': payments.map((k, v) => MapEntry(k, v.toJson())),
        'receipt': receipt?.toJson(),
      };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        cadence: (j['cadence'] ?? 'monthly') as String,
        payer: (j['payer'] ?? '') as String,
        participants: ((j['participants'] as List?) ?? []).map((e) => e.toString()).toList(),
        split: (j['split'] ?? 'equal') as String,
        shares: ((j['shares'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        paidBy: ((j['paidBy'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v as bool)),
        payments: ((j['payments'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), Payment.fromJson(v as Map<String, dynamic>))),
        receipt: Attachment.fromJson(j['receipt'] as Map<String, dynamic>?),
      );
}

class Necessity {
  String id;
  String item;
  String mode; // 'shared' | 'individual'
  String payer; // whoever bought the goods
  double amount;
  String date;
  String split; // 'equal' | 'percentage'
  List<String> participants; // who the cost is divided between
  Map<String, double> shares; // per-person owed amount
  Map<String, bool> paidBy; // who has reimbursed the buyer
  Map<String, Payment> payments; // saved reimbursement history, by name + date

  Necessity({
    required this.id,
    required this.item,
    required this.mode,
    required this.payer,
    required this.amount,
    required this.date,
    this.split = 'equal',
    List<String>? participants,
    Map<String, double>? shares,
    Map<String, bool>? paidBy,
    Map<String, Payment>? payments,
  })  : participants = participants ?? [],
        shares = shares ?? {},
        paidBy = paidBy ?? {},
        payments = payments ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'mode': mode,
        'payer': payer,
        'amount': amount,
        'date': date,
        'split': split,
        'participants': participants,
        'shares': shares,
        'paidBy': paidBy,
        'payments': payments.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Necessity.fromJson(Map<String, dynamic> j) => Necessity(
        id: (j['id'] ?? '') as String,
        item: (j['item'] ?? '') as String,
        mode: (j['mode'] ?? 'shared') as String,
        payer: (j['payer'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        date: (j['date'] ?? '') as String,
        split: (j['split'] ?? 'equal') as String,
        participants: ((j['participants'] as List?) ?? []).map((e) => e.toString()).toList(),
        shares: ((j['shares'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        paidBy: ((j['paidBy'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v as bool)),
        payments: ((j['payments'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), Payment.fromJson(v as Map<String, dynamic>))),
      );
}

class Grocery {
  String id;
  String title;
  double total;
  String payer;
  String mode;
  String split;
  Map<String, double> shares;
  String date;
  Attachment? receipt;
  Map<String, bool> paidBy;
  Map<String, Payment> payments;

  Grocery({
    required this.id,
    required this.title,
    required this.total,
    required this.payer,
    required this.mode,
    this.split = 'equal',
    required this.shares,
    required this.date,
    this.receipt,
    Map<String, bool>? paidBy,
    Map<String, Payment>? payments,
  })  : paidBy = paidBy ?? {},
        payments = payments ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'total': total,
        'payer': payer,
        'mode': mode,
        'split': split,
        'shares': shares,
        'date': date,
        'receipt': receipt?.toJson(),
        'paidBy': paidBy,
        'payments': payments.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Grocery.fromJson(Map<String, dynamic> j) => Grocery(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        total: ((j['total'] ?? 0) as num).toDouble(),
        payer: (j['payer'] ?? '') as String,
        mode: (j['mode'] ?? 'shared') as String,
        split: (j['split'] ?? 'equal') as String,
        shares: ((j['shares'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        date: (j['date'] ?? '') as String,
        receipt: Attachment.fromJson(j['receipt'] as Map<String, dynamic>?),
        paidBy: ((j['paidBy'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v as bool)),
        payments: ((j['payments'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), Payment.fromJson(v as Map<String, dynamic>))),
      );
}

class CleaningRosterEntry {
  String day;
  String area;
  String assignee;
  CleaningRosterEntry({required this.day, required this.area, required this.assignee});
  Map<String, dynamic> toJson() => {'day': day, 'area': area, 'assignee': assignee};
  factory CleaningRosterEntry.fromJson(Map<String, dynamic> j) => CleaningRosterEntry(
        day: (j['day'] ?? '') as String,
        area: (j['area'] ?? '') as String,
        assignee: (j['assignee'] ?? '') as String,
      );
}

class CleaningTask {
  String id;
  String task;
  String assignee;
  String dueDate;
  bool done;
  Attachment? photo;
  Attachment? receipt;
  String? excuse;
  String? completedAt;

  CleaningTask({
    required this.id,
    required this.task,
    required this.assignee,
    required this.dueDate,
    this.done = false,
    this.photo,
    this.receipt,
    this.excuse,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'task': task,
        'assignee': assignee,
        'dueDate': dueDate,
        'done': done,
        'photo': photo?.toJson(),
        'receipt': receipt?.toJson(),
        'excuse': excuse,
        'completedAt': completedAt,
      };
  factory CleaningTask.fromJson(Map<String, dynamic> j) => CleaningTask(
        id: (j['id'] ?? '') as String,
        task: (j['task'] ?? '') as String,
        assignee: (j['assignee'] ?? '') as String,
        dueDate: (j['dueDate'] ?? '') as String,
        done: (j['done'] ?? false) as bool,
        photo: Attachment.fromJson(j['photo'] as Map<String, dynamic>?),
        receipt: Attachment.fromJson(j['receipt'] as Map<String, dynamic>?),
        excuse: j['excuse'] as String?,
        completedAt: j['completedAt'] as String?,
      );
}

class CleaningDayAvailability {
  String userId;
  String day; // 'Mon' | 'Tue' | ...
  String status; // 'available' | 'na'

  CleaningDayAvailability({required this.userId, required this.day, required this.status});

  Map<String, dynamic> toJson() => {'userId': userId, 'day': day, 'status': status};

  factory CleaningDayAvailability.fromJson(Map<String, dynamic> j) => CleaningDayAvailability(
        userId: (j['userId'] ?? '') as String,
        day: (j['day'] ?? '') as String,
        status: (j['status'] ?? '') as String,
      );
}

// ── Maintenance contacts ──────────────────────────────────────────────────────

class MaintenanceContact {
  String id;
  String name;
  String category; // 'emergency' | 'property' | 'utilities' | 'trades' | 'other'
  String? phone;
  String? email;
  String? notes;
  String addedBy;
  String addedAt;

  MaintenanceContact({
    required this.id,
    required this.name,
    this.category = 'other',
    this.phone,
    this.email,
    this.notes,
    required this.addedBy,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'phone': phone,
        'email': email,
        'notes': notes,
        'addedBy': addedBy,
        'addedAt': addedAt,
      };

  factory MaintenanceContact.fromJson(Map<String, dynamic> j) =>
      MaintenanceContact(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        category: (j['category'] ?? 'other') as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        notes: j['notes'] as String?,
        addedBy: (j['addedBy'] ?? '') as String,
        addedAt: (j['addedAt'] ?? '') as String,
      );
}

// ── Welcome guide ────────────────────────────────────────────────────────────

class WelcomeSection {
  String id;
  String icon;
  String title;
  String content;

  WelcomeSection({
    required this.id,
    this.icon = '',
    required this.title,
    this.content = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'icon': icon,
        'title': title,
        'content': content,
      };

  factory WelcomeSection.fromJson(Map<String, dynamic> j) => WelcomeSection(
        id: (j['id'] ?? '') as String,
        icon: (j['icon'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        content: (j['content'] ?? '') as String,
      );
}

class WelcomeGuide {
  String message;
  List<WelcomeSection> sections;

  WelcomeGuide({this.message = '', List<WelcomeSection>? sections})
      : sections = sections ?? [];

  Map<String, dynamic> toJson() => {
        'message': message,
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory WelcomeGuide.fromJson(Map<String, dynamic> j) => WelcomeGuide(
        message: (j['message'] ?? '') as String,
        sections: ((j['sections'] as List?) ?? [])
            .map((e) => WelcomeSection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A request from one housemate to swap an assigned cleaning task or roster day
/// with another. Exactly one of [taskId] or [rosterDay] will be set.
class ChoreSwapRequest {
  String id;
  String? taskId;      // set for single-task swaps
  String? rosterDay;   // the day the requester is offering (their own day)
  String? wantedDay;   // the day they want back in exchange (mutual swap only)
  String fromUserId;
  String fromUserName;
  String? toUserId; // null = open to any housemate
  String? toUserName;
  String? note;
  String requestedAt;
  String status; // 'pending' | 'accepted' | 'declined' | 'cancelled'
  String? respondedAt;
  String? respondedBy;
  String? respondedByName;

  ChoreSwapRequest({
    required this.id,
    this.taskId,
    this.rosterDay,
    this.wantedDay,
    required this.fromUserId,
    required this.fromUserName,
    this.toUserId,
    this.toUserName,
    this.note,
    required this.requestedAt,
    this.status = 'pending',
    this.respondedAt,
    this.respondedBy,
    this.respondedByName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'rosterDay': rosterDay,
        'wantedDay': wantedDay,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'toUserId': toUserId,
        'toUserName': toUserName,
        'note': note,
        'requestedAt': requestedAt,
        'status': status,
        'respondedAt': respondedAt,
        'respondedBy': respondedBy,
        'respondedByName': respondedByName,
      };

  factory ChoreSwapRequest.fromJson(Map<String, dynamic> j) => ChoreSwapRequest(
        id: (j['id'] ?? '') as String,
        taskId: j['taskId'] as String?,
        rosterDay: j['rosterDay'] as String?,
        wantedDay: j['wantedDay'] as String?,
        fromUserId: (j['fromUserId'] ?? '') as String,
        fromUserName: (j['fromUserName'] ?? '') as String,
        toUserId: j['toUserId'] as String?,
        toUserName: j['toUserName'] as String?,
        note: j['note'] as String?,
        requestedAt: (j['requestedAt'] ?? '') as String,
        status: (j['status'] ?? 'pending') as String,
        respondedAt: j['respondedAt'] as String?,
        respondedBy: j['respondedBy'] as String?,
        respondedByName: j['respondedByName'] as String?,
      );
}

class RentShare {
  String userId;
  double amount;
  bool hasParking;
  bool hasBalcony;
  bool hasPrivateWashroom;
  String? reason;

  RentShare({
    required this.userId,
    required this.amount,
    this.hasParking = false,
    this.hasBalcony = false,
    this.hasPrivateWashroom = false,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'amount': amount,
        'hasParking': hasParking,
        'hasBalcony': hasBalcony,
        'hasPrivateWashroom': hasPrivateWashroom,
        'reason': reason,
      };

  factory RentShare.fromJson(Map<String, dynamic> j) => RentShare(
        userId: (j['userId'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        hasParking: (j['hasParking'] ?? false) as bool,
        hasBalcony: (j['hasBalcony'] ?? false) as bool,
        hasPrivateWashroom: (j['hasPrivateWashroom'] ?? false) as bool,
        reason: j['reason'] as String?,
      );
}

class Party {
  String id;
  String title;
  String date;
  String time;
  String host;
  String notes;
  Map<String, String> responses;
  String status;

  Party({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.host,
    this.notes = '',
    Map<String, String>? responses,
    this.status = 'planning',
  }) : responses = responses ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'time': time,
        'host': host,
        'notes': notes,
        'responses': responses,
        'status': status,
      };
  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        time: (j['time'] ?? '') as String,
        host: (j['host'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        responses: ((j['responses'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
        status: (j['status'] ?? 'planning') as String,
      );
}

class PollOption {
  String id;
  String text;
  String addedBy;
  PollOption({required this.id, required this.text, required this.addedBy});
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'addedBy': addedBy};
  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
        id: (j['id'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        addedBy: (j['addedBy'] ?? '') as String,
      );
}

class MessagePoll {
  String question;
  bool multi;
  bool closed;
  List<PollOption> options;
  // optionId -> list of userIds who voted for it
  Map<String, List<String>> votes;

  MessagePoll({
    required this.question,
    this.multi = false,
    this.closed = false,
    List<PollOption>? options,
    Map<String, List<String>>? votes,
  })  : options = options ?? [],
        votes = votes ?? {};

  Map<String, dynamic> toJson() => {
        'question': question,
        'multi': multi,
        'closed': closed,
        'options': options.map((o) => o.toJson()).toList(),
        'votes': votes,
      };

  factory MessagePoll.fromJson(Map<String, dynamic> j) => MessagePoll(
        question: (j['question'] ?? '') as String,
        multi: (j['multi'] ?? false) as bool,
        closed: (j['closed'] ?? false) as bool,
        options: ((j['options'] as List?) ?? []).map((o) => PollOption.fromJson(o as Map<String, dynamic>)).toList(),
        votes: ((j['votes'] as Map?) ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()),
        ),
      );
}

class Message {
  String id;
  String from;
  String text;
  String at;
  String type; // 'text' | 'poll' | 'image' | 'video' | 'voice'
  MessagePoll? poll;
  // Photo / video / voice payload for media messages.
  Attachment? media;
  bool pinned;

  Message({
    required this.id,
    required this.from,
    required this.text,
    required this.at,
    this.type = 'text',
    this.poll,
    this.media,
    this.pinned = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'text': text,
        'at': at,
        'type': type,
        'poll': poll?.toJson(),
        'media': media?.toJson(),
        'pinned': pinned,
      };

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: (j['id'] ?? '') as String,
        from: (j['from'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        at: (j['at'] ?? '') as String,
        type: (j['type'] ?? 'text') as String,
        poll: j['poll'] != null ? MessagePoll.fromJson(j['poll'] as Map<String, dynamic>) : null,
        media: Attachment.fromJson(j['media'] as Map<String, dynamic>?),
        pinned: (j['pinned'] ?? false) as bool,
      );
}

class Messages {
  List<Message> group;
  Map<String, List<Message>> dms;
  Messages({required this.group, required this.dms});
  Map<String, dynamic> toJson() => {
        'group': group.map((m) => m.toJson()).toList(),
        'dms': dms.map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList())),
      };
  factory Messages.fromJson(Map<String, dynamic> j) => Messages(
        group: ((j['group'] as List?) ?? []).map((m) => Message.fromJson(m as Map<String, dynamic>)).toList(),
        dms: ((j['dms'] as Map?) ?? {}).map(
          (k, v) => MapEntry(
            k.toString(),
            (v as List).map((m) => Message.fromJson(m as Map<String, dynamic>)).toList(),
          ),
        ),
      );
}

class Complaint {
  String id;
  String against;
  String from;
  String reason;
  int severity;
  String date;
  String status;
  // Extended fields — null-safe for backward compatibility
  String? kind;           // 'peer' | 'leaseholder'
  String? category;       // see _lhCategories in complaints UI
  String? incidentDate;   // ISO date of when it happened (may differ from filed date)
  bool anonymous;         // hide filer name from leaseholder view
  Attachment? evidence;

  Complaint({
    required this.id,
    required this.against,
    required this.from,
    required this.reason,
    required this.severity,
    required this.date,
    this.status = 'open',
    this.kind,
    this.category,
    this.incidentDate,
    this.anonymous = false,
    this.evidence,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'against': against,
        'from': from,
        'reason': reason,
        'severity': severity,
        'date': date,
        'status': status,
        if (kind != null) 'kind': kind,
        if (category != null) 'category': category,
        if (incidentDate != null) 'incidentDate': incidentDate,
        'anonymous': anonymous,
        if (evidence != null) 'evidence': evidence!.toJson(),
      };

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: (j['id'] ?? '') as String,
        against: (j['against'] ?? '') as String,
        from: (j['from'] ?? '') as String,
        reason: (j['reason'] ?? '') as String,
        severity: ((j['severity'] ?? 1) as num).toInt(),
        date: (j['date'] ?? '') as String,
        status: (j['status'] ?? 'open') as String,
        kind: j['kind'] as String?,
        category: j['category'] as String?,
        incidentDate: j['incidentDate'] as String?,
        anonymous: (j['anonymous'] ?? false) as bool,
        evidence: j['evidence'] != null ? Attachment.fromJson(j['evidence'] as Map<String, dynamic>) : null,
      );
}

class Deduction {
  String reason;
  double amount;
  Deduction({required this.reason, required this.amount});
  Map<String, dynamic> toJson() => {'reason': reason, 'amount': amount};
  factory Deduction.fromJson(Map<String, dynamic> j) => Deduction(
        reason: (j['reason'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
      );
}

class Notice {
  String id;
  String userId;
  String givenAt;
  String leaveDate;
  String reason;
  String bondReturn;
  List<Deduction> deductions;
  String deductionExplanation;
  bool? tenantAgreed;

  Notice({
    required this.id,
    required this.userId,
    required this.givenAt,
    required this.leaveDate,
    this.reason = '',
    this.bondReturn = 'after-agent',
    List<Deduction>? deductions,
    this.deductionExplanation = '',
    this.tenantAgreed,
  }) : deductions = deductions ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'givenAt': givenAt,
        'leaveDate': leaveDate,
        'reason': reason,
        'bondReturn': bondReturn,
        'deductions': deductions.map((d) => d.toJson()).toList(),
        'deductionExplanation': deductionExplanation,
        'tenantAgreed': tenantAgreed,
      };
  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: (j['id'] ?? '') as String,
        userId: (j['userId'] ?? '') as String,
        givenAt: (j['givenAt'] ?? '') as String,
        leaveDate: (j['leaveDate'] ?? '') as String,
        reason: (j['reason'] ?? '') as String,
        bondReturn: (j['bondReturn'] ?? 'after-agent') as String,
        deductions: ((j['deductions'] as List?) ?? []).map((d) => Deduction.fromJson(d as Map<String, dynamic>)).toList(),
        deductionExplanation: (j['deductionExplanation'] ?? '') as String,
        tenantAgreed: j['tenantAgreed'] as bool?,
      );
}

class TerminationExpense {
  String id;
  String reason;
  double amount;
  TerminationExpense({required this.id, required this.reason, required this.amount});
  Map<String, dynamic> toJson() => {'id': id, 'reason': reason, 'amount': amount};
  factory TerminationExpense.fromJson(Map<String, dynamic> j) => TerminationExpense(
        id: (j['id'] ?? '') as String,
        reason: (j['reason'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
      );
}

class TerminationPlan {
  List<TerminationExpense> expenses;
  String splitMode;
  Map<String, double> customShares;
  String notes;

  TerminationPlan({
    List<TerminationExpense>? expenses,
    this.splitMode = 'equal',
    Map<String, double>? customShares,
    this.notes = '',
  })  : expenses = expenses ?? [],
        customShares = customShares ?? {};

  Map<String, dynamic> toJson() => {
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'splitMode': splitMode,
        'customShares': customShares,
        'notes': notes,
      };

  factory TerminationPlan.fromJson(Map<String, dynamic> j) => TerminationPlan(
        expenses: ((j['expenses'] as List?) ?? []).map((e) => TerminationExpense.fromJson(e as Map<String, dynamic>)).toList(),
        splitMode: (j['splitMode'] ?? 'equal') as String,
        customShares: ((j['customShares'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        notes: (j['notes'] ?? '') as String,
      );
}

class Issue {
  String id;
  String title;
  String category; // plumbing|appliance|electrical|structure|pest|other
  String description;
  Attachment? photo;
  String raisedBy;
  String raisedAt;
  String status; // open|fixed
  String? fixedAt;
  String? fixedBy;

  Issue({
    required this.id,
    required this.title,
    this.category = 'other',
    this.description = '',
    this.photo,
    required this.raisedBy,
    required this.raisedAt,
    this.status = 'open',
    this.fixedAt,
    this.fixedBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'description': description,
        'photo': photo?.toJson(),
        'raisedBy': raisedBy,
        'raisedAt': raisedAt,
        'status': status,
        'fixedAt': fixedAt,
        'fixedBy': fixedBy,
      };

  factory Issue.fromJson(Map<String, dynamic> j) => Issue(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        category: (j['category'] ?? 'other') as String,
        description: (j['description'] ?? '') as String,
        photo: Attachment.fromJson(j['photo'] as Map<String, dynamic>?),
        raisedBy: (j['raisedBy'] ?? '') as String,
        raisedAt: (j['raisedAt'] ?? '') as String,
        status: (j['status'] ?? 'open') as String,
        fixedAt: j['fixedAt'] as String?,
        fixedBy: j['fixedBy'] as String?,
      );
}

/// Records that a specific tenant paid their rent share for a given period.
class RentPayment {
  String id;
  String userId;
  String userName;
  double amount;
  String paidAt; // ISO timestamp
  String periodStart; // ISO date — identifies which rent period this covers
  String? confirmedBy; // who marked it paid if different from the payer
  Attachment? proof; // optional bank transfer screenshot

  RentPayment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.paidAt,
    required this.periodStart,
    this.confirmedBy,
    this.proof,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'amount': amount,
        'paidAt': paidAt,
        'periodStart': periodStart,
        'confirmedBy': confirmedBy,
        'proof': proof?.toJson(),
      };

  factory RentPayment.fromJson(Map<String, dynamic> j) => RentPayment(
        id: (j['id'] ?? '') as String,
        userId: (j['userId'] ?? '') as String,
        userName: (j['userName'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        paidAt: (j['paidAt'] ?? '') as String,
        periodStart: (j['periodStart'] ?? '') as String,
        confirmedBy: j['confirmedBy'] as String?,
        proof: Attachment.fromJson(j['proof'] as Map<String, dynamic>?),
      );
}

/// A personal (non-shared) expense the user wants to track against their own budget.
class PersonalExpense {
  String id;
  String userId;
  // 'grocery' | 'necessity' | 'subscription' | 'other'
  String category;
  String title;
  double amount;
  String date; // ISO date string (YYYY-MM-DD)
  String? note;

  PersonalExpense({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'category': category,
        'title': title,
        'amount': amount,
        'date': date,
        'note': note,
      };

  factory PersonalExpense.fromJson(Map<String, dynamic> j) => PersonalExpense(
        id: (j['id'] ?? '') as String,
        userId: (j['userId'] ?? '') as String,
        category: (j['category'] ?? 'other') as String,
        title: (j['title'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        date: (j['date'] ?? '') as String,
        note: j['note'] as String?,
      );
}

/// Device-local notification preferences for the signed-in user.
class NotificationPrefs {
  bool rent;
  bool bills;
  bool chores;
  bool parties;
  int hour; // hour of day to fire reminders (0–23)
  bool darkMode;
  bool essentialServices;

  NotificationPrefs({
    this.rent = true,
    this.bills = true,
    this.chores = true,
    this.parties = true,
    this.hour = 8,
    this.darkMode = false,
    this.essentialServices = true,
  });

  Map<String, dynamic> toJson() => {
        'rent': rent,
        'bills': bills,
        'chores': chores,
        'parties': parties,
        'hour': hour,
        'darkMode': darkMode,
        'essentialServices': essentialServices,
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        rent: (j['rent'] ?? true) as bool,
        bills: (j['bills'] ?? true) as bool,
        chores: (j['chores'] ?? true) as bool,
        parties: (j['parties'] ?? true) as bool,
        hour: ((j['hour'] ?? 8) as num).toInt(),
        darkMode: (j['darkMode'] ?? false) as bool,
        essentialServices: (j['essentialServices'] ?? true) as bool,
      );
}

class CalendarNote {
  String id;
  String userId;
  String title;
  String date; // ISO date YYYY-MM-DD
  String? note;

  CalendarNote({required this.id, required this.userId, required this.title, required this.date, this.note});

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'date': date,
        'note': note,
      };

  static CalendarNote fromJson(Map<String, dynamic> j) => CalendarNote(
        id: (j['id'] ?? '') as String,
        userId: (j['userId'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        note: j['note'] as String?,
      );
}

/// A live shared shopping list item that any housemate can add, tick off, or remove.
class ShoppingItem {
  String id;
  String text;
  String addedBy;
  String addedByName;
  String addedAt; // ISO timestamp
  bool done;
  String? doneBy;
  String? doneByName;
  String? doneAt;

  ShoppingItem({
    required this.id,
    required this.text,
    required this.addedBy,
    required this.addedByName,
    required this.addedAt,
    this.done = false,
    this.doneBy,
    this.doneByName,
    this.doneAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'addedBy': addedBy,
        'addedByName': addedByName,
        'addedAt': addedAt,
        'done': done,
        'doneBy': doneBy,
        'doneByName': doneByName,
        'doneAt': doneAt,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
        id: (j['id'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        addedBy: (j['addedBy'] ?? '') as String,
        addedByName: (j['addedByName'] ?? '') as String,
        addedAt: (j['addedAt'] ?? '') as String,
        done: (j['done'] ?? false) as bool,
        doneBy: j['doneBy'] as String?,
        doneByName: j['doneByName'] as String?,
        doneAt: j['doneAt'] as String?,
      );
}

class AppNotification {
  String id;
  String kind; // 'payment_request' | 'rent_request'
  String title;
  String body;
  String at; // ISO timestamp
  String forUserId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.forUserId,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'body': body,
        'at': at,
        'forUserId': forUserId,
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] ?? '') as String,
        kind: (j['kind'] ?? 'payment_request') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        at: (j['at'] ?? '') as String,
        forUserId: (j['forUserId'] ?? '') as String,
        isRead: (j['isRead'] ?? false) as bool,
      );
}

class HouseTerms {
  int minStayMonths;
  int earlyLeaveBondPct;      // bond % if leaving before minStayMonths
  int midLeaveBondPct;        // bond % if leaving between minStay and 6 months
  int lateLeaveBondPct;       // bond % if leaving after 6 months
  int noticePeriodDays;       // days of notice required before vacating
  int lateRentGraceDays;      // grace days before late fees kick in
  double lateRentFeePerDay;   // AUD per day after grace period
  bool petsAllowed;
  int maxGuestNightsPerWeek;
  String quietHoursStart;     // "HH:MM" 24-hr
  String quietHoursEnd;
  bool smokingAllowed;
  bool sublettingAllowed;
  String? customClauses;

  HouseTerms({
    this.minStayMonths = 3,
    this.earlyLeaveBondPct = 50,
    this.midLeaveBondPct = 10,
    this.lateLeaveBondPct = 20,
    this.noticePeriodDays = 21,
    this.lateRentGraceDays = 3,
    this.lateRentFeePerDay = 0,
    this.petsAllowed = false,
    this.maxGuestNightsPerWeek = 2,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '08:00',
    this.smokingAllowed = false,
    this.sublettingAllowed = false,
    this.customClauses,
  });

  Map<String, dynamic> toJson() => {
        'minStayMonths': minStayMonths,
        'earlyLeaveBondPct': earlyLeaveBondPct,
        'midLeaveBondPct': midLeaveBondPct,
        'lateLeaveBondPct': lateLeaveBondPct,
        'noticePeriodDays': noticePeriodDays,
        'lateRentGraceDays': lateRentGraceDays,
        'lateRentFeePerDay': lateRentFeePerDay,
        'petsAllowed': petsAllowed,
        'maxGuestNightsPerWeek': maxGuestNightsPerWeek,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'smokingAllowed': smokingAllowed,
        'sublettingAllowed': sublettingAllowed,
        'customClauses': customClauses,
      };

  factory HouseTerms.fromJson(Map<String, dynamic> j) => HouseTerms(
        minStayMonths: ((j['minStayMonths'] ?? 3) as num).toInt(),
        earlyLeaveBondPct: ((j['earlyLeaveBondPct'] ?? 50) as num).toInt(),
        midLeaveBondPct: ((j['midLeaveBondPct'] ?? 10) as num).toInt(),
        lateLeaveBondPct: ((j['lateLeaveBondPct'] ?? 20) as num).toInt(),
        noticePeriodDays: ((j['noticePeriodDays'] ?? 21) as num).toInt(),
        lateRentGraceDays: ((j['lateRentGraceDays'] ?? 3) as num).toInt(),
        lateRentFeePerDay: ((j['lateRentFeePerDay'] ?? 0) as num).toDouble(),
        petsAllowed: (j['petsAllowed'] ?? false) as bool,
        maxGuestNightsPerWeek: ((j['maxGuestNightsPerWeek'] ?? 2) as num).toInt(),
        quietHoursStart: (j['quietHoursStart'] ?? '22:00') as String,
        quietHoursEnd: (j['quietHoursEnd'] ?? '08:00') as String,
        smokingAllowed: (j['smokingAllowed'] ?? false) as bool,
        sublettingAllowed: (j['sublettingAllowed'] ?? false) as bool,
        customClauses: j['customClauses'] as String?,
      );
}

class ApplianceBooking {
  String id;
  String appliance;
  String userId;
  String userName;
  String date; // ISO date YYYY-MM-DD
  String slot; // e.g. '8:00 AM – 10:00 AM'
  String? note;
  String createdAt;

  ApplianceBooking({
    required this.id,
    required this.appliance,
    required this.userId,
    required this.userName,
    required this.date,
    required this.slot,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'appliance': appliance,
        'userId': userId,
        'userName': userName,
        'date': date,
        'slot': slot,
        'note': note,
        'createdAt': createdAt,
      };

  factory ApplianceBooking.fromJson(Map<String, dynamic> j) => ApplianceBooking(
        id: (j['id'] ?? '') as String,
        appliance: (j['appliance'] ?? '') as String,
        userId: (j['userId'] ?? '') as String,
        userName: (j['userName'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        slot: (j['slot'] ?? '') as String,
        note: j['note'] as String?,
        createdAt: (j['createdAt'] ?? '') as String,
      );
}

class ConditionItem {
  String id;
  String area;
  String condition; // 'good' | 'fair' | 'poor'
  String notes;
  Attachment? photo;

  ConditionItem({
    required this.id,
    required this.area,
    required this.condition,
    this.notes = '',
    this.photo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'area': area,
        'condition': condition,
        'notes': notes,
        'photo': photo?.toJson(),
      };

  factory ConditionItem.fromJson(Map<String, dynamic> j) => ConditionItem(
        id: (j['id'] ?? '') as String,
        area: (j['area'] ?? '') as String,
        condition: (j['condition'] ?? 'good') as String,
        notes: (j['notes'] ?? '') as String,
        photo: Attachment.fromJson(j['photo'] as Map<String, dynamic>?),
      );
}

class ConditionCheck {
  String id;
  String type; // 'move-in' | 'move-out'
  String userId;
  String userName;
  String createdBy;
  String createdAt;
  List<ConditionItem> items;
  String? notes;

  ConditionCheck({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    required this.createdBy,
    required this.createdAt,
    List<ConditionItem>? items,
    this.notes,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'userId': userId,
        'userName': userName,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'items': items.map((i) => i.toJson()).toList(),
        'notes': notes,
      };

  factory ConditionCheck.fromJson(Map<String, dynamic> j) => ConditionCheck(
        id: (j['id'] ?? '') as String,
        type: (j['type'] ?? 'move-in') as String,
        userId: (j['userId'] ?? '') as String,
        userName: (j['userName'] ?? '') as String,
        createdBy: (j['createdBy'] ?? '') as String,
        createdAt: (j['createdAt'] ?? '') as String,
        items: ((j['items'] as List?) ?? [])
            .map((e) => ConditionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: j['notes'] as String?,
      );
}

class Session {
  String? userId;
  Map<String, dynamic>? pendingSignup;
  Session({this.userId, this.pendingSignup});
  Map<String, dynamic> toJson() => {'userId': userId, 'pendingSignup': pendingSignup};
  factory Session.fromJson(Map<String, dynamic> j) =>
      Session(userId: j['userId'] as String?, pendingSignup: j['pendingSignup'] as Map<String, dynamic>?);
}

class LeaseholderReview {
  String id;
  String leaseholderId;
  String fromUserId;
  String fromUserName;
  bool anonymous;
  int rating; // 1–5
  String body;
  String date; // ISO date

  LeaseholderReview({
    required this.id,
    required this.leaseholderId,
    required this.fromUserId,
    required this.fromUserName,
    this.anonymous = false,
    required this.rating,
    required this.body,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'leaseholderId': leaseholderId,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'anonymous': anonymous,
        'rating': rating,
        'body': body,
        'date': date,
      };

  factory LeaseholderReview.fromJson(Map<String, dynamic> j) => LeaseholderReview(
        id: (j['id'] ?? '') as String,
        leaseholderId: (j['leaseholderId'] ?? '') as String,
        fromUserId: (j['fromUserId'] ?? '') as String,
        fromUserName: (j['fromUserName'] ?? '') as String,
        anonymous: (j['anonymous'] ?? false) as bool,
        rating: ((j['rating'] ?? 3) as num).toInt(),
        body: (j['body'] ?? '') as String,
        date: (j['date'] ?? '') as String,
      );
}

// A rating left on a Marketplace (GoodsListing) or Essentials (EssentialListing)
// post, for either direction: a buyer/consumer rating the seller/business, or
// the seller/business rating a specific buyer/consumer back. Mirrors
// [LeaseholderReview]'s shape (1-5 stars + optional body + optional
// anonymity) — [listingId] scopes it to the post the interaction happened on,
// [targetUserId] is whoever is being reviewed.
class ListingReview {
  String id;
  String listingId;
  String targetUserId;
  String targetUserName;
  String fromUserId;
  String fromUserName;
  bool anonymous;
  int rating; // 1–5
  String body;
  String date; // ISO date

  ListingReview({
    required this.id,
    required this.listingId,
    required this.targetUserId,
    required this.targetUserName,
    required this.fromUserId,
    required this.fromUserName,
    this.anonymous = false,
    required this.rating,
    required this.body,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'listingId': listingId,
        'targetUserId': targetUserId,
        'targetUserName': targetUserName,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'anonymous': anonymous,
        'rating': rating,
        'body': body,
        'date': date,
      };

  factory ListingReview.fromJson(Map<String, dynamic> j) => ListingReview(
        id: (j['id'] ?? '') as String,
        listingId: (j['listingId'] ?? '') as String,
        targetUserId: (j['targetUserId'] ?? '') as String,
        targetUserName: (j['targetUserName'] ?? '') as String,
        fromUserId: (j['fromUserId'] ?? '') as String,
        fromUserName: (j['fromUserName'] ?? '') as String,
        anonymous: (j['anonymous'] ?? false) as bool,
        rating: ((j['rating'] ?? 3) as num).toInt(),
        body: (j['body'] ?? '') as String,
        date: (j['date'] ?? '') as String,
      );
}

class Listing {
  String id;
  String type; // 'tenant-wanted' (room available) | 'room-wanted' (seeker)
  String by;
  String title;
  String suburb;
  double? rent; // $/wk, tenant-wanted
  double? budget; // $/wk, room-wanted
  String? availableFrom;
  String description;
  String status; // 'open' | 'closed'
  String createdAt;
  bool billsIncluded;
  String? alcoholPref;   // 'yes' | 'no' | 'social'
  String? smokingPref;   // 'yes' | 'no' | 'outside'
  String? genderPref;    // 'any' | 'female' | 'male' | 'non-binary'
  bool hasPool;
  bool hasParking;

  Listing({
    required this.id,
    required this.type,
    required this.by,
    required this.title,
    this.suburb = '',
    this.rent,
    this.budget,
    this.availableFrom,
    this.description = '',
    this.status = 'open',
    required this.createdAt,
    this.billsIncluded = false,
    this.alcoholPref,
    this.smokingPref,
    this.genderPref,
    this.hasPool = false,
    this.hasParking = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'by': by,
        'title': title,
        'suburb': suburb,
        'rent': rent,
        'budget': budget,
        'availableFrom': availableFrom,
        'description': description,
        'status': status,
        'createdAt': createdAt,
        'billsIncluded': billsIncluded,
        'alcoholPref': alcoholPref,
        'smokingPref': smokingPref,
        'genderPref': genderPref,
        'hasPool': hasPool,
        'hasParking': hasParking,
      };

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: (j['id'] ?? '') as String,
        type: (j['type'] ?? 'tenant-wanted') as String,
        by: (j['by'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        suburb: (j['suburb'] ?? '') as String,
        rent: (j['rent'] as num?)?.toDouble(),
        budget: (j['budget'] as num?)?.toDouble(),
        availableFrom: j['availableFrom'] as String?,
        description: (j['description'] ?? '') as String,
        status: (j['status'] ?? 'open') as String,
        createdAt: (j['createdAt'] ?? '') as String,
        billsIncluded: (j['billsIncluded'] as bool?) ?? false,
        alcoholPref: j['alcoholPref'] as String?,
        smokingPref: j['smokingPref'] as String?,
        genderPref: j['genderPref'] as String?,
        hasPool: (j['hasPool'] as bool?) ?? false,
        hasParking: (j['hasParking'] as bool?) ?? false,
      );
}

class ListingInterest {
  String id;
  String listingId;
  String from;
  String to;
  String message;
  Map<String, String> sharedFields; // name / email / phone / moveInDate
  // When a tenant applies cold (vs being invited) they share these too.
  Lifestyle? lifestyle;
  EmergencyContact? emergency;
  String status; // 'pending' | 'accepted' | 'declined'
  String createdAt;
  // Set when a leaseholder accepts — the invite code created for this
  // applicant, so the applicant's device can auto-join once it sees this
  // interest marked accepted.
  String? inviteCode;

  ListingInterest({
    required this.id,
    required this.listingId,
    required this.from,
    required this.to,
    this.message = '',
    Map<String, String>? sharedFields,
    this.lifestyle,
    this.emergency,
    this.status = 'pending',
    required this.createdAt,
    this.inviteCode,
  }) : sharedFields = sharedFields ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'listingId': listingId,
        'from': from,
        'to': to,
        'message': message,
        'sharedFields': sharedFields,
        'lifestyle': lifestyle?.toJson(),
        'emergency': emergency?.toJson(),
        'status': status,
        'createdAt': createdAt,
        'inviteCode': inviteCode,
        // Write-only derived index: lets the client query this private record
        // with `where('participants', arrayContains: myUid)`. Ignored by
        // fromJson — recomputed from `from`/`to` on every write.
        'participants': [from, to].where((x) => x.isNotEmpty).toSet().toList(),
      };

  factory ListingInterest.fromJson(Map<String, dynamic> j) => ListingInterest(
        id: (j['id'] ?? '') as String,
        listingId: (j['listingId'] ?? '') as String,
        from: (j['from'] ?? '') as String,
        to: (j['to'] ?? '') as String,
        message: (j['message'] ?? '') as String,
        sharedFields: ((j['sharedFields'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
        lifestyle: Lifestyle.fromJson(j['lifestyle'] as Map<String, dynamic>?),
        emergency: EmergencyContact.fromJson(j['emergency'] as Map<String, dynamic>?),
        status: (j['status'] ?? 'pending') as String,
        createdAt: (j['createdAt'] ?? '') as String,
        inviteCode: j['inviteCode'] as String?,
      );
}

/// A request from a prospective housemate to inspect the property (usually a
/// specific room listing). The leaseholder confirms or declines a time.
class Inspection {
  String id;
  String? listingId; // room being inspected, if any
  String requestedBy; // user who wants to view
  String to; // leaseholder / poster who confirms
  String date; // iso date
  String slot; // time, e.g. '10:00 am'
  String note;
  String status; // 'requested' | 'confirmed' | 'declined'
  String createdAt;

  Inspection({
    required this.id,
    this.listingId,
    required this.requestedBy,
    required this.to,
    required this.date,
    this.slot = '',
    this.note = '',
    this.status = 'requested',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'listingId': listingId,
        'requestedBy': requestedBy,
        'to': to,
        'date': date,
        'slot': slot,
        'note': note,
        'status': status,
        'createdAt': createdAt,
        // Write-only derived index for `where('participants', arrayContains:)`.
        // Ignored by fromJson — recomputed from `requestedBy`/`to` on write.
        'participants': [requestedBy, to].where((x) => x.isNotEmpty).toSet().toList(),
      };

  factory Inspection.fromJson(Map<String, dynamic> j) => Inspection(
        id: (j['id'] ?? '') as String,
        listingId: j['listingId'] as String?,
        requestedBy: (j['requestedBy'] ?? '') as String,
        to: (j['to'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        slot: (j['slot'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        status: (j['status'] ?? 'requested') as String,
        createdAt: (j['createdAt'] ?? '') as String,
      );
}

/// A point-in-time tenant track-record a tenant can attach to a post thread
/// when a leaseholder asks for their performance / reference.
class PerfSnapshot {
  int standing; // 0..100
  String band; // 'Good' | 'Fair' | 'Needs attention'
  int doneCount;
  int taskCount;
  double? choreRate;
  int paidCount;
  int billCount;
  double? billRate;
  int complaintSeverity;
  int partiesHosted;
  String house; // address / context the record is from
  String? note; // optional free-text from the tenant
  String? subject; // display name of the tenant the reference is about (set when a leaseholder vouches)
  String? subjectId; // user id of the tenant the reference is about — use this to match, not subject
  Lifestyle? lifestyle; // snapshot of the tenant's lifestyle answers

  PerfSnapshot({
    required this.standing,
    required this.band,
    this.doneCount = 0,
    this.taskCount = 0,
    this.choreRate,
    this.paidCount = 0,
    this.billCount = 0,
    this.billRate,
    this.complaintSeverity = 0,
    this.partiesHosted = 0,
    this.house = '',
    this.note,
    this.subject,
    this.subjectId,
    this.lifestyle,
  });

  Map<String, dynamic> toJson() => {
        'standing': standing,
        'band': band,
        'doneCount': doneCount,
        'taskCount': taskCount,
        'choreRate': choreRate,
        'paidCount': paidCount,
        'billCount': billCount,
        'billRate': billRate,
        'complaintSeverity': complaintSeverity,
        'partiesHosted': partiesHosted,
        'house': house,
        'note': note,
        'subject': subject,
        'subjectId': subjectId,
        'lifestyle': lifestyle?.toJson(),
      };

  static PerfSnapshot? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return PerfSnapshot(
      standing: ((j['standing'] ?? 0) as num).toInt(),
      band: (j['band'] ?? '') as String,
      doneCount: ((j['doneCount'] ?? 0) as num).toInt(),
      taskCount: ((j['taskCount'] ?? 0) as num).toInt(),
      choreRate: (j['choreRate'] as num?)?.toDouble(),
      paidCount: ((j['paidCount'] ?? 0) as num).toInt(),
      billCount: ((j['billCount'] ?? 0) as num).toInt(),
      billRate: (j['billRate'] as num?)?.toDouble(),
      complaintSeverity: ((j['complaintSeverity'] ?? 0) as num).toInt(),
      partiesHosted: ((j['partiesHosted'] ?? 0) as num).toInt(),
      house: (j['house'] ?? '') as String,
      note: j['note'] as String?,
      subject: j['subject'] as String?,
      subjectId: j['subjectId'] as String?,
      lifestyle: Lifestyle.fromJson(j['lifestyle'] as Map<String, dynamic>?),
    );
  }
}

/// A direct message inside a single post's conversation. The conversation for a
/// post is always between the poster (listing.by) and one interested housemate,
/// so a thread is identified by (listingId, the non-poster participant).
class PostMessage {
  String id;
  String listingId;
  String from;
  String to;
  String text;
  String at;
  String kind; // 'text' | 'perf-request' | 'perf-share'
  PerfSnapshot? perf;
  Attachment? attachment;

  PostMessage({
    required this.id,
    required this.listingId,
    required this.from,
    required this.to,
    this.text = '',
    required this.at,
    this.kind = 'text',
    this.perf,
    this.attachment,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'listingId': listingId,
        'from': from,
        'to': to,
        'text': text,
        'at': at,
        'kind': kind,
        'perf': perf?.toJson(),
        'attachment': attachment?.toJson(),
        // Write-only derived index for `where('participants', arrayContains:)`.
        // Ignored by fromJson — recomputed from `from`/`to` on write.
        'participants': [from, to].where((x) => x.isNotEmpty).toSet().toList(),
      };

  factory PostMessage.fromJson(Map<String, dynamic> j) => PostMessage(
        id: (j['id'] ?? '') as String,
        listingId: (j['listingId'] ?? '') as String,
        from: (j['from'] ?? '') as String,
        to: (j['to'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        at: (j['at'] ?? '') as String,
        kind: (j['kind'] ?? 'text') as String,
        perf: PerfSnapshot.fromJson(j['perf'] as Map<String, dynamic>?),
        attachment: Attachment.fromJson(j['attachment'] as Map<String, dynamic>?),
      );
}

class ParkingBooking {
  String id;
  String spot;
  String userId;
  String userName;
  String date; // ISO date YYYY-MM-DD
  String? note;
  String createdAt;

  ParkingBooking({
    required this.id,
    required this.spot,
    required this.userId,
    required this.userName,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'spot': spot,
        'userId': userId,
        'userName': userName,
        'date': date,
        'note': note,
        'createdAt': createdAt,
      };

  factory ParkingBooking.fromJson(Map<String, dynamic> j) => ParkingBooking(
        id: (j['id'] ?? '') as String,
        spot: (j['spot'] ?? '') as String,
        userId: (j['userId'] ?? '') as String,
        userName: (j['userName'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        note: j['note'] as String?,
        createdAt: (j['createdAt'] ?? '') as String,
      );
}

// ─── EssentialListing ─────────────────────────────────────────────────────────

class EssentialListing {
  String id;
  String postedBy;
  String businessName;
  String category; // removal | haircut | cleaning | agency | driving | other
  String description;
  String? phone;
  String? website;
  String? hours; // free text, e.g. "Mon-Fri 9am-5pm"
  String? address; // free text, e.g. "12 Smith St, Parramatta"
  String postedAt;
  List<String> likes;
  // Distinct viewer user IDs, deduped so repeat views by the same person
  // don't inflate the count. Drives the business owner's "views" analytics.
  List<String> viewedBy;

  EssentialListing({
    required this.id,
    required this.postedBy,
    required this.businessName,
    required this.category,
    required this.description,
    this.phone,
    this.website,
    this.hours,
    this.address,
    required this.postedAt,
    List<String>? likes,
    List<String>? viewedBy,
  })  : likes = likes ?? [],
        viewedBy = viewedBy ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'postedBy': postedBy,
        'businessName': businessName,
        'category': category,
        'description': description,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        if (hours != null) 'hours': hours,
        if (address != null) 'address': address,
        'postedAt': postedAt,
        'likes': likes,
        'viewedBy': viewedBy,
      };

  factory EssentialListing.fromJson(Map<String, dynamic> j) => EssentialListing(
        id: (j['id'] ?? '') as String,
        postedBy: (j['postedBy'] as String?) ?? '',
        businessName: (j['businessName'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'other',
        description: (j['description'] as String?) ?? '',
        phone: j['phone'] as String?,
        website: j['website'] as String?,
        hours: j['hours'] as String?,
        address: j['address'] as String?,
        postedAt: (j['postedAt'] as String?) ?? '',
        likes: List<String>.from((j['likes'] as List?) ?? []),
        viewedBy: List<String>.from((j['viewedBy'] as List?) ?? []),
      );
}

// ─── EssentialBooking ─────────────────────────────────────────────────────────

class EssentialBooking {
  String id;
  String listingId; // EssentialListing.id
  String requestedBy; // client user id
  String businessOwnerId; // EssentialListing.postedBy at time of request
  String date; // ISO date YYYY-MM-DD
  String slot; // time, e.g. '10:00 am'
  String note;
  String status; // 'pending' | 'confirmed' | 'declined' | 'cancelled'
  String createdAt;
  String updatedAt;
  // If set, the client wants this appointment to repeat — 'weekly' |
  // 'fortnightly' | 'monthly' (same cadence vocabulary as Property.rentCadence).
  // Null means a one-off appointment (the default).
  String? frequency;

  EssentialBooking({
    required this.id,
    required this.listingId,
    required this.requestedBy,
    required this.businessOwnerId,
    required this.date,
    this.slot = '',
    this.note = '',
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.frequency,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'listingId': listingId,
        'requestedBy': requestedBy,
        'businessOwnerId': businessOwnerId,
        'date': date,
        'slot': slot,
        'note': note,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'frequency': frequency,
        // Write-only derived index for `where('participants', arrayContains:)`.
        // Ignored by fromJson — recomputed from `requestedBy`/`businessOwnerId`.
        'participants': [requestedBy, businessOwnerId].where((x) => x.isNotEmpty).toSet().toList(),
      };

  factory EssentialBooking.fromJson(Map<String, dynamic> j) => EssentialBooking(
        id: (j['id'] ?? '') as String,
        listingId: (j['listingId'] ?? '') as String,
        requestedBy: (j['requestedBy'] ?? '') as String,
        businessOwnerId: (j['businessOwnerId'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        slot: (j['slot'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        status: (j['status'] ?? 'pending') as String,
        createdAt: (j['createdAt'] ?? '') as String,
        updatedAt: (j['updatedAt'] ?? '') as String,
        frequency: j['frequency'] as String?,
      );
}

// ─── GoodsListing ─────────────────────────────────────────────────────────────

class GoodsListing {
  String id;
  String postedBy;
  String title;
  String description;
  double price;
  String category; // furniture | electronics | appliances | kitchenware | books | clothing | sports | other
  String condition; // new | like_new | good | fair | used
  String? location;
  List<Attachment> photos; // max 3, enforced in the post-item UI
  String status; // 'available' | 'sold'
  String postedAt;
  // Distinct viewer user IDs, deduped so repeat views by the same person
  // don't inflate the count. Drives the business owner's "views" analytics.
  List<String> viewedBy;

  GoodsListing({
    required this.id,
    required this.postedBy,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    this.condition = 'good',
    this.location,
    List<Attachment>? photos,
    this.status = 'available',
    required this.postedAt,
    List<String>? viewedBy,
  })  : photos = photos ?? [],
        viewedBy = viewedBy ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'postedBy': postedBy,
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'condition': condition,
        'location': location,
        'photos': photos.map((p) => p.toJson()).toList(),
        'status': status,
        'postedAt': postedAt,
        'viewedBy': viewedBy,
      };

  factory GoodsListing.fromJson(Map<String, dynamic> j) => GoodsListing(
        id: (j['id'] ?? '') as String,
        postedBy: (j['postedBy'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        price: ((j['price'] ?? 0) as num).toDouble(),
        category: (j['category'] ?? 'other') as String,
        condition: (j['condition'] ?? 'good') as String,
        location: j['location'] as String?,
        photos: ((j['photos'] as List?) ?? [])
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>?))
            .whereType<Attachment>()
            .toList(),
        status: (j['status'] ?? 'available') as String,
        postedAt: (j['postedAt'] ?? '') as String,
        viewedBy: List<String>.from((j['viewedBy'] as List?) ?? []),
      );
}
