// All entities are simple mutable classes; we serialise to JSON for
// shared_preferences persistence. Mirrors the React mockData shape.

class Attachment {
  String? fileName;
  String? dataUrl;
  String? type;
  int? size;
  String? uploadedAt;
  // Duration in milliseconds, for audio/video attachments (voice notes, clips).
  int? durationMs;

  Attachment({this.fileName, this.dataUrl, this.type, this.size, this.uploadedAt, this.durationMs});

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'dataUrl': dataUrl,
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
  String? dataUrl;
  String? type;
  int? size;
  String? uploadedAt;

  IdDocSubmission({this.kind, this.fileName, this.dataUrl, this.type, this.size, this.uploadedAt});

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'fileName': fileName,
        'dataUrl': dataUrl,
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
      type: j['type'] as String?,
      size: (j['size'] as num?)?.toInt(),
      uploadedAt: j['uploadedAt'] as String?,
    );
  }
}

class PaymentSubmission {
  String? method;
  String? fileName;
  String? dataUrl;
  String? type;
  int? size;
  String? uploadedAt;

  PaymentSubmission({this.method, this.fileName, this.dataUrl, this.type, this.size, this.uploadedAt});

  Map<String, dynamic> toJson() => {
        'method': method,
        'fileName': fileName,
        'dataUrl': dataUrl,
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
  String relationship; // single | relationship | married
  String pets; // none | has-pets
  String diet; // none | vegetarian | vegan | halal | other
  String occupation; // free text
  String schedule; // early-bird | flexible | night-owl
  String guests; // rarely | sometimes | often
  String about; // free-text intro

  Lifestyle({
    this.smoking = '',
    this.alcohol = '',
    this.relationship = '',
    this.pets = '',
    this.diet = '',
    this.occupation = '',
    this.schedule = '',
    this.guests = '',
    this.about = '',
  });

  /// The core questions we require everyone to answer.
  bool get isComplete =>
      smoking.isNotEmpty && alcohol.isNotEmpty && relationship.isNotEmpty && pets.isNotEmpty && schedule.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'smoking': smoking,
        'alcohol': alcohol,
        'relationship': relationship,
        'pets': pets,
        'diet': diet,
        'occupation': occupation,
        'schedule': schedule,
        'guests': guests,
        'about': about,
      };

  static Lifestyle? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return Lifestyle(
      smoking: (j['smoking'] ?? '') as String,
      alcohol: (j['alcohol'] ?? '') as String,
      relationship: (j['relationship'] ?? '') as String,
      pets: (j['pets'] ?? '') as String,
      diet: (j['diet'] ?? '') as String,
      occupation: (j['occupation'] ?? '') as String,
      schedule: (j['schedule'] ?? '') as String,
      guests: (j['guests'] ?? '') as String,
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
  String role; // 'admin' | 'leaseholder' | 'tenant'
  String email;
  String phone;
  String? moveInDate;
  String? moveOutDate;
  bool bondPaid;
  double bondAmount;
  bool docVerified;
  bool advanceRentPaid;
  String? acceptedRulesAt;
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
  Submissions? submissions;
  // Leaseholder-only: their lease agreement submission for admin verification.
  LeaseVerification? leaseVerification;

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
    this.pending = false,
    this.member = true,
    this.lifestyle,
    this.emergency,
    this.shareEmergency = false,
    this.submissions,
    this.leaseVerification,
  });

  bool get isAdmin => role == 'admin';
  bool get isLeaseholder => role == 'leaseholder';
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
        'pending': pending,
        'member': member,
        'lifestyle': lifestyle?.toJson(),
        'emergency': emergency?.toJson(),
        'shareEmergency': shareEmergency,
        'submissions': submissions?.toJson(),
        'leaseVerification': leaseVerification?.toJson(),
      };

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        name: j['name'] as String,
        initials: j['initials'] as String,
        role: j['role'] as String,
        email: (j['email'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        moveInDate: j['moveInDate'] as String?,
        moveOutDate: j['moveOutDate'] as String?,
        bondPaid: (j['bondPaid'] ?? false) as bool,
        bondAmount: ((j['bondAmount'] ?? 0) as num).toDouble(),
        docVerified: (j['docVerified'] ?? false) as bool,
        advanceRentPaid: (j['advanceRentPaid'] ?? false) as bool,
        acceptedRulesAt: j['acceptedRulesAt'] as String?,
        pending: (j['pending'] ?? false) as bool,
        member: (j['member'] ?? true) as bool,
        lifestyle: Lifestyle.fromJson(j['lifestyle'] as Map<String, dynamic>?),
        emergency: EmergencyContact.fromJson(j['emergency'] as Map<String, dynamic>?),
        shareEmergency: (j['shareEmergency'] ?? false) as bool,
        submissions: Submissions.fromJson(j['submissions'] as Map<String, dynamic>?),
        leaseVerification: LeaseVerification.fromJson(j['leaseVerification'] as Map<String, dynamic>?),
      );
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
      };

  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: j['id'] as String,
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
      );
}

class Invite {
  String code;
  String email;
  String role;
  String sentAt;
  String status;

  Invite({required this.code, required this.email, required this.role, required this.sentAt, this.status = 'sent'});

  Map<String, dynamic> toJson() => {'code': code, 'email': email, 'role': role, 'sentAt': sentAt, 'status': status};
  factory Invite.fromJson(Map<String, dynamic> j) => Invite(
        code: j['code'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        sentAt: j['sentAt'] as String,
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
        id: j['id'] as String,
        text: j['text'] as String,
        addedBy: j['addedBy'] as String,
        addedAt: j['addedAt'] as String,
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
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        title: j['title'] as String,
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
        id: j['id'] as String,
        title: j['title'] as String,
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

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.cadence,
    required this.payer,
    required this.participants,
    this.split = 'equal',
    required this.shares,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'cadence': cadence,
        'payer': payer,
        'participants': participants,
        'split': split,
        'shares': shares,
      };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        cadence: (j['cadence'] ?? 'monthly') as String,
        payer: (j['payer'] ?? '') as String,
        participants: ((j['participants'] as List?) ?? []).map((e) => e.toString()).toList(),
        split: (j['split'] ?? 'equal') as String,
        shares: ((j['shares'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
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
        id: j['id'] as String,
        item: j['item'] as String,
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
  });
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
      };
  factory Grocery.fromJson(Map<String, dynamic> j) => Grocery(
        id: j['id'] as String,
        title: j['title'] as String,
        total: ((j['total'] ?? 0) as num).toDouble(),
        payer: (j['payer'] ?? '') as String,
        mode: (j['mode'] ?? 'shared') as String,
        split: (j['split'] ?? 'equal') as String,
        shares: ((j['shares'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        date: (j['date'] ?? '') as String,
        receipt: Attachment.fromJson(j['receipt'] as Map<String, dynamic>?),
      );
}

class CleaningRosterEntry {
  String day;
  String area;
  String assignee;
  CleaningRosterEntry({required this.day, required this.area, required this.assignee});
  Map<String, dynamic> toJson() => {'day': day, 'area': area, 'assignee': assignee};
  factory CleaningRosterEntry.fromJson(Map<String, dynamic> j) => CleaningRosterEntry(
        day: j['day'] as String,
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
  String? excuse;
  String? completedAt;

  CleaningTask({
    required this.id,
    required this.task,
    required this.assignee,
    required this.dueDate,
    this.done = false,
    this.photo,
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
        'excuse': excuse,
        'completedAt': completedAt,
      };
  factory CleaningTask.fromJson(Map<String, dynamic> j) => CleaningTask(
        id: j['id'] as String,
        task: j['task'] as String,
        assignee: (j['assignee'] ?? '') as String,
        dueDate: (j['dueDate'] ?? '') as String,
        done: (j['done'] ?? false) as bool,
        photo: Attachment.fromJson(j['photo'] as Map<String, dynamic>?),
        excuse: j['excuse'] as String?,
        completedAt: j['completedAt'] as String?,
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
        id: j['id'] as String,
        title: j['title'] as String,
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
        id: j['id'] as String,
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

  Message({
    required this.id,
    required this.from,
    required this.text,
    required this.at,
    this.type = 'text',
    this.poll,
    this.media,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'text': text,
        'at': at,
        'type': type,
        'poll': poll?.toJson(),
        'media': media?.toJson(),
      };

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        from: j['from'] as String,
        text: (j['text'] ?? '') as String,
        at: j['at'] as String,
        type: (j['type'] ?? 'text') as String,
        poll: j['poll'] != null ? MessagePoll.fromJson(j['poll'] as Map<String, dynamic>) : null,
        media: Attachment.fromJson(j['media'] as Map<String, dynamic>?),
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
  Complaint({
    required this.id,
    required this.against,
    required this.from,
    required this.reason,
    required this.severity,
    required this.date,
    this.status = 'open',
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'against': against,
        'from': from,
        'reason': reason,
        'severity': severity,
        'date': date,
        'status': status,
      };
  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: j['id'] as String,
        against: j['against'] as String,
        from: j['from'] as String,
        reason: (j['reason'] ?? '') as String,
        severity: ((j['severity'] ?? 1) as num).toInt(),
        date: (j['date'] ?? '') as String,
        status: (j['status'] ?? 'open') as String,
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
        id: j['id'] as String,
        userId: j['userId'] as String,
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
        id: j['id'] as String,
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
        id: j['id'] as String,
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

class Session {
  String? userId;
  Map<String, dynamic>? pendingSignup;
  Session({this.userId, this.pendingSignup});
  Map<String, dynamic> toJson() => {'userId': userId, 'pendingSignup': pendingSignup};
  factory Session.fromJson(Map<String, dynamic> j) =>
      Session(userId: j['userId'] as String?, pendingSignup: j['pendingSignup'] as Map<String, dynamic>?);
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
      };

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as String,
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
      };

  factory ListingInterest.fromJson(Map<String, dynamic> j) => ListingInterest(
        id: j['id'] as String,
        listingId: (j['listingId'] ?? '') as String,
        from: (j['from'] ?? '') as String,
        to: (j['to'] ?? '') as String,
        message: (j['message'] ?? '') as String,
        sharedFields: ((j['sharedFields'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
        lifestyle: Lifestyle.fromJson(j['lifestyle'] as Map<String, dynamic>?),
        emergency: EmergencyContact.fromJson(j['emergency'] as Map<String, dynamic>?),
        status: (j['status'] ?? 'pending') as String,
        createdAt: (j['createdAt'] ?? '') as String,
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
      };

  factory Inspection.fromJson(Map<String, dynamic> j) => Inspection(
        id: j['id'] as String,
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
  String? subject; // tenant the reference is about (set when a leaseholder vouches)

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

  PostMessage({
    required this.id,
    required this.listingId,
    required this.from,
    required this.to,
    this.text = '',
    required this.at,
    this.kind = 'text',
    this.perf,
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
      };

  factory PostMessage.fromJson(Map<String, dynamic> j) => PostMessage(
        id: j['id'] as String,
        listingId: (j['listingId'] ?? '') as String,
        from: (j['from'] ?? '') as String,
        to: (j['to'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        at: (j['at'] ?? '') as String,
        kind: (j['kind'] ?? 'text') as String,
        perf: PerfSnapshot.fromJson(j['perf'] as Map<String, dynamic>?),
      );
}
