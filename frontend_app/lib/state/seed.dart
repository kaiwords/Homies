import '../util/format.dart';
import 'models.dart';

class SeedData {
  // Open the demo signed in as the primary leaseholder (Maya).
  static Session session() => Session(userId: 'u1');

  static Property property() => Property(
        id: 'p1',
        address: '12 Marrickville Road, Marrickville NSW 2204',
        type: 'House',
        bedrooms: 4,
        bathrooms: 2,
        features: {
          'parking': true,
          'laundry': true,
          'dishwasher': true,
          'aircon': true,
          'backyard': true,
        },
        agent: 'Harbourside Property Group',
        agentContact: 'lettings@harbourside.com.au',
        leaseStart: '2025-09-01',
        leaseEnd: '2026-08-31',
        rentAmount: 980,
        rentCadence: 'weekly',
        rentStartDate: '2025-09-01',
        bondWeeks: 4,
        advanceWeeks: 2,
        maxOccupants: 5,
        setupComplete: true,
      );

  // 1 platform admin + 2 leaseholders + 3 tenants.
  static List<User> users() => [
        User(
          id: 'u0',
          name: 'Homies Admin',
          initials: 'HA',
          role: 'admin',
          email: 'admin@homies.app',
          phone: '0400 000 000',
          member: false,
        ),
        User(
          id: 'u1',
          name: 'Maya Chen',
          initials: 'MC',
          role: 'leaseholder',
          email: 'maya.chen@example.com',
          phone: '0412 334 556',
          moveInDate: '2025-09-01',
          bondPaid: true,
          bondAmount: 784,
          docVerified: true,
          advanceRentPaid: true,
          acceptedRulesAt: '2025-09-01T09:00:00.000',
          lifestyle: Lifestyle(
            smoking: 'non-smoker',
            alcohol: 'social',
            relationship: 'relationship',
            pets: 'none',
            schedule: 'early-bird',
            guests: 'sometimes',
            diet: 'vegetarian',
            occupation: 'UX designer',
          ),
          emergency: EmergencyContact(name: 'Grace Chen', relationship: 'Sister', phone: '0412 998 221'),
          // Already verified by the admin.
          leaseVerification: LeaseVerification(
            fullName: 'Maya Chen',
            phone: '0412 334 556',
            email: 'maya.chen@example.com',
            agreement: Attachment(fileName: 'lease-marrickville.pdf', type: 'application/pdf', size: 248000),
            status: 'verified',
            submittedAt: '2025-08-25T10:00:00.000',
            reviewedAt: '2025-08-26T14:20:00.000',
          ),
        ),
        User(
          id: 'u2',
          name: 'Daniel Okafor',
          initials: 'DO',
          role: 'leaseholder',
          email: 'daniel.okafor@example.com',
          phone: '0423 778 219',
          moveInDate: '2025-09-01',
          bondPaid: true,
          bondAmount: 784,
          docVerified: true,
          advanceRentPaid: true,
          acceptedRulesAt: '2025-09-01T09:30:00.000',
          lifestyle: Lifestyle(
            smoking: 'outside-only',
            alcohol: 'social',
            relationship: 'single',
            pets: 'none',
            schedule: 'flexible',
            guests: 'rarely',
            diet: 'none',
            occupation: 'Software engineer',
          ),
          emergency: EmergencyContact(name: 'Chidi Okafor', relationship: 'Brother', phone: '0423 110 887'),
          // Submitted, awaiting the admin's review.
          leaseVerification: LeaseVerification(
            fullName: 'Daniel Okafor',
            phone: '0423 778 219',
            email: 'daniel.okafor@example.com',
            agreement: Attachment(fileName: 'tenancy-agreement.pdf', type: 'application/pdf', size: 196000),
            status: 'pending',
            submittedAt: '2026-06-15T11:30:00.000',
          ),
        ),
        User(
          id: 'u3',
          name: 'Priya Sharma',
          initials: 'PS',
          role: 'tenant',
          email: 'priya.sharma@example.com',
          phone: '0431 902 564',
          moveInDate: '2025-09-15',
          bondPaid: true,
          bondAmount: 784,
          docVerified: true,
          advanceRentPaid: true,
          acceptedRulesAt: '2025-09-14T18:10:00.000',
          lifestyle: Lifestyle(
            smoking: 'non-smoker',
            alcohol: 'none',
            relationship: 'single',
            pets: 'none',
            schedule: 'early-bird',
            guests: 'rarely',
            diet: 'halal',
            occupation: 'Nurse',
          ),
          emergency: EmergencyContact(name: 'Anita Sharma', relationship: 'Mother', phone: '0431 552 109'),
        ),
        User(
          id: 'u4',
          name: 'Tom Becker',
          initials: 'TB',
          role: 'tenant',
          email: 'tom.becker@example.com',
          phone: '0438 145 770',
          moveInDate: '2025-10-01',
          bondPaid: true,
          bondAmount: 784,
          docVerified: true,
          advanceRentPaid: false,
          acceptedRulesAt: '2025-09-30T12:45:00.000',
          lifestyle: Lifestyle(
            smoking: 'non-smoker',
            alcohol: 'regular',
            relationship: 'single',
            pets: 'has-pets',
            schedule: 'night-owl',
            guests: 'sometimes',
            diet: 'none',
            occupation: 'Engineering student',
          ),
          emergency: EmergencyContact(name: 'Lena Becker', relationship: 'Mother', phone: '0438 220 654'),
        ),
        User(
          id: 'u5',
          name: 'Aisha Rahman',
          initials: 'AR',
          role: 'tenant',
          email: 'aisha.rahman@example.com',
          phone: '0420 663 118',
          moveInDate: '2026-02-01',
          bondPaid: false,
          bondAmount: 784,
          docVerified: false,
          advanceRentPaid: false,
          pending: true,
        ),
      ];

  static List<Invite> invites() => [];
  static List<HouseRule> rules() => [];

  // A few demo bills, including saved payment records (by name + date) so the
  // "who paid, and when" history is visible the moment the demo loads.
  static List<Bill> bills() => [
        Bill(
          id: 'b1',
          title: 'Electricity — AGL (Mar–May)',
          category: 'utility',
          amount: 312.40,
          periodStart: '2026-03-01',
          periodEnd: '2026-05-31',
          dueDate: '2026-05-20',
          issuedBy: 'u1',
          split: 'equal',
          shares: {'u1': 78.10, 'u2': 78.10, 'u3': 78.10, 'u4': 78.10},
          status: 'settled',
          paidBy: {'u1': true, 'u2': true, 'u3': true, 'u4': true},
          payments: {
            'u1': Payment(payerId: 'u1', payerName: 'Maya Chen', at: '2026-05-16T09:24:00.000', amount: 78.10),
            'u2': Payment(payerId: 'u2', payerName: 'Daniel Okafor', at: '2026-05-17T18:02:00.000', amount: 78.10),
            'u3': Payment(payerId: 'u3', payerName: 'Priya Sharma', at: '2026-05-18T07:41:00.000', amount: 78.10),
            'u4': Payment(
                payerId: 'u4',
                payerName: 'Tom Becker',
                confirmedBy: 'Maya Chen',
                at: '2026-05-19T20:15:00.000',
                amount: 78.10),
          },
        ),
        Bill(
          id: 'b2',
          title: 'NBN internet — May',
          category: 'internet',
          amount: 89,
          periodStart: '2026-05-01',
          periodEnd: '2026-05-31',
          dueDate: '2026-05-28',
          issuedBy: 'u2',
          split: 'equal',
          shares: {'u1': 22.25, 'u2': 22.25, 'u3': 22.25, 'u4': 22.25},
          status: 'pending',
          paidBy: {'u1': true, 'u2': true, 'u3': true},
          payments: {
            'u1': Payment(payerId: 'u1', payerName: 'Maya Chen', at: '2026-05-26T10:05:00.000', amount: 22.25),
            'u2': Payment(payerId: 'u2', payerName: 'Daniel Okafor', at: '2026-05-26T12:30:00.000', amount: 22.25),
            'u3': Payment(payerId: 'u3', payerName: 'Priya Sharma', at: '2026-05-27T08:50:00.000', amount: 22.25),
          },
        ),
        Bill(
          id: 'b3',
          title: 'Water — Q1 (Sydney Water)',
          category: 'water',
          amount: 180,
          periodStart: '2026-03-01',
          periodEnd: '2026-05-31',
          dueDate: '2026-06-10',
          issuedBy: 'u1',
          split: 'equal',
          shares: {'u1': 45.00, 'u2': 45.00, 'u3': 45.00, 'u4': 45.00},
          status: 'pending',
        ),
      ];
  static List<BillSchedule> schedules() => [];
  static List<Subscription> subscriptions() => [];
  static List<Necessity> necessities() => [];
  static List<Grocery> groceries() => [];
  // Weekly cleaning roster — each housemate owns a day + area.
  static List<CleaningRosterEntry> roster() => [
        CleaningRosterEntry(day: 'Mon', area: 'Kitchen', assignee: 'u3'),
        CleaningRosterEntry(day: 'Wed', area: 'Bathrooms', assignee: 'u4'),
        CleaningRosterEntry(day: 'Fri', area: 'Common areas & floors', assignee: 'u1'),
        CleaningRosterEntry(day: 'Sun', area: 'Bins & recycling', assignee: 'u2'),
      ];

  static List<CleaningTask> tasks() => [
        CleaningTask(id: 'c1', task: 'Scrub the oven', assignee: 'u3', dueDate: daysAheadIso(2)),
        CleaningTask(id: 'c2', task: 'Vacuum the living room', assignee: 'u4', dueDate: daysAheadIso(1)),
        CleaningTask(id: 'c3', task: 'Wipe down the bathroom mirrors', assignee: 'u4', dueDate: daysAgoIso(1)),
      ];
  static List<Party> parties() => [];

  // A few demo posts in the group chat.
  static Messages messages() => Messages(
        group: [
          Message(
            id: 'm1',
            from: 'u1',
            text: 'Welcome to the house group chat everyone! 🏡 Please drop your details on the Housemates page when you get a sec.',
            at: '2025-09-15T19:02:00.000',
          ),
          Message(
            id: 'm2',
            from: 'u2',
            text: 'Bins go out Tuesday nights — red lid weekly, yellow lid fortnightly. I\'ll set a reminder on the cleaning roster.',
            at: '2025-09-16T08:24:00.000',
          ),
          Message(
            id: 'm3',
            from: 'u3',
            text: 'Thanks Maya! Just moved my stuff in, kitchen shelf on the left is mine 🙌',
            at: '2025-09-16T17:48:00.000',
          ),
          Message(
            id: 'm4',
            from: 'u4',
            text: 'Internet is up and running — NBN 100. Login details are on the fridge whiteboard.',
            at: '2025-10-02T11:15:00.000',
          ),
          Message(
            id: 'm5',
            from: 'u1',
            text: 'Quick one: who\'s around for a house dinner this Sunday? Thinking we split groceries and cook together 🍝',
            at: '2026-05-28T20:05:00.000',
          ),
          Message(
            id: 'm6',
            from: 'u5',
            text: 'Count me in! I can bring dessert 🍰',
            at: '2026-05-28T20:11:00.000',
          ),
        ],
        dms: {},
      );

  static List<Complaint> complaints() => [];
  static List<Issue> issues() => [];

  // Demo posts in the room/housemate marketplace — from both leaseholders
  // (advertising the spare room) and tenants (scouting their next place).
  static List<Listing> listings() => [
        Listing(
          id: 'l1',
          type: 'tenant-wanted',
          by: 'u1', // Maya (leaseholder)
          title: 'Sunny double room in our Marrickville terrace',
          suburb: 'Marrickville',
          rent: 290,
          availableFrom: '2026-06-15',
          description:
              'Big north-facing double in a friendly 4-bed terrace. Sharing with two tenants and a leaseholder — tidy, social but respectful. Walk to Marrickville Metro and the cafés on Illawarra Rd.',
          createdAt: '2026-05-30',
        ),
        Listing(
          id: 'l2',
          type: 'tenant-wanted',
          by: 'u2', // Daniel (leaseholder)
          title: 'Quiet room, 5 min walk to the station',
          suburb: 'Marrickville',
          rent: 270,
          availableFrom: '2026-07-01',
          description:
              'Cosy single room, perfect for someone who works from home. Quiet professional household, dishwasher, off-street parking and a sunny backyard.',
          createdAt: '2026-05-26',
        ),
        Listing(
          id: 'l3',
          type: 'room-wanted',
          by: 'u3', // Priya (tenant)
          title: 'Tidy nurse after a room in the inner west',
          suburb: 'Inner West',
          budget: 320,
          availableFrom: '2026-06-20',
          description:
              'Day-shift nurse, very clean and easy-going. Looking for a calm sharehouse near Marrickville or Dulwich Hill. Happy to share references from my current place.',
          createdAt: '2026-05-28',
        ),
        Listing(
          id: 'l4',
          type: 'room-wanted',
          by: 'u4', // Tom (tenant)
          title: 'Easy-going grad student looking for a room',
          suburb: 'Newtown / Marrickville',
          budget: 250,
          availableFrom: '2026-07-10',
          description:
              'Final-year engineering student, mostly on campus during the week. Tidy, love to cook, keen to find a sociable but laid-back house.',
          createdAt: '2026-05-22',
        ),
      ];

  static List<ListingInterest> listingInterests() => [];
  static List<Inspection> inspections() => [];

  // A demo in-post conversation showing a leaseholder asking a prospective
  // tenant for their track record, and the tenant sharing a reference card.
  static List<PostMessage> postMessages() => [
        PostMessage(
          id: 'pm1',
          listingId: 'l1',
          from: 'u3', // Priya
          to: 'u1', // Maya
          text: 'Hi Maya! Your double room looks lovely — is it still free from mid-June?',
          at: '2026-05-31T09:12:00.000',
        ),
        PostMessage(
          id: 'pm2',
          listingId: 'l1',
          from: 'u1',
          to: 'u3',
          text:
              "Hi Priya! Yes, it's available from the 15th 🙂 The house is pretty tidy so we like to get a feel for how new housemates run things.",
          at: '2026-05-31T10:02:00.000',
        ),
        PostMessage(
          id: 'pm3',
          listingId: 'l1',
          from: 'u1',
          to: 'u3',
          kind: 'perf-request',
          text: 'Maya asked for your housemate track record.',
          at: '2026-05-31T10:03:00.000',
        ),
        PostMessage(
          id: 'pm4',
          listingId: 'l1',
          from: 'u3',
          to: 'u1',
          kind: 'perf-share',
          text: 'Happy to — here’s my record from my current place.',
          at: '2026-05-31T10:20:00.000',
          perf: PerfSnapshot(
            standing: 92,
            band: 'Good',
            doneCount: 11,
            taskCount: 12,
            choreRate: 11 / 12,
            paidCount: 8,
            billCount: 8,
            billRate: 1.0,
            complaintSeverity: 0,
            partiesHosted: 1,
            house: '12 Marrickville Road, Marrickville NSW 2204',
            note: 'Always paid bills on time and never had a complaint. Happy to give a phone reference too!',
          ),
        ),
        PostMessage(
          id: 'pm5',
          listingId: 'l1',
          from: 'u1',
          to: 'u3',
          text: "That's a great record — want to drop by Saturday arvo to see the place?",
          at: '2026-05-31T11:05:00.000',
        ),
        PostMessage(
          id: 'pm6',
          listingId: 'l2',
          from: 'u4', // Tom
          to: 'u2', // Daniel
          text: 'Hey Daniel, is the quiet room still going? I work from home a couple of days so it sounds perfect.',
          at: '2026-05-27T14:30:00.000',
        ),
      ];
}
