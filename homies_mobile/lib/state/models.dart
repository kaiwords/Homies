// All entities are simple mutable classes; we serialise to JSON for
// shared_preferences persistence. Mirrors the React mockData shape.

class Attachment {
  String? fileName;
  String? dataUrl;
  String? type;
  int? size;
  String? uploadedAt;

  Attachment({this.fileName, this.dataUrl, this.type, this.size, this.uploadedAt});

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'dataUrl': dataUrl,
        'type': type,
        'size': size,
        'uploadedAt': uploadedAt,
      };

  static Attachment? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return Attachment(
      fileName: j['fileName'] as String?,
      dataUrl: j['dataUrl'] as String?,
      type: j['type'] as String?,
      size: (j['size'] as num?)?.toInt(),
      uploadedAt: j['uploadedAt'] as String?,
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

class User {
  String id;
  String name;
  String initials;
  String role; // 'leaseholder' | 'tenant'
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
  Submissions? submissions;

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
    this.submissions,
  });

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
        'submissions': submissions?.toJson(),
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
        submissions: Submissions.fromJson(j['submissions'] as Map<String, dynamic>?),
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
    this.scheduleId,
    this.proof,
  }) : paidBy = paidBy ?? {};

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
  String mode;
  String payer;
  double amount;
  String date;
  Necessity({required this.id, required this.item, required this.mode, required this.payer, required this.amount, required this.date});
  Map<String, dynamic> toJson() => {'id': id, 'item': item, 'mode': mode, 'payer': payer, 'amount': amount, 'date': date};
  factory Necessity.fromJson(Map<String, dynamic> j) => Necessity(
        id: j['id'] as String,
        item: j['item'] as String,
        mode: (j['mode'] ?? 'shared') as String,
        payer: (j['payer'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toDouble(),
        date: (j['date'] ?? '') as String,
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
  String type; // 'text' | 'poll'
  MessagePoll? poll;

  Message({
    required this.id,
    required this.from,
    required this.text,
    required this.at,
    this.type = 'text',
    this.poll,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'text': text,
        'at': at,
        'type': type,
        'poll': poll?.toJson(),
      };

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        from: j['from'] as String,
        text: (j['text'] ?? '') as String,
        at: j['at'] as String,
        type: (j['type'] ?? 'text') as String,
        poll: j['poll'] != null ? MessagePoll.fromJson(j['poll'] as Map<String, dynamic>) : null,
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
