import 'models.dart';

class SeedData {
  static Session session() => Session();

  static Property property() => Property(
        id: 'p1',
        address: '',
        type: 'House',
        bedrooms: 1,
        bathrooms: 1,
        features: {},
        agent: '',
        agentContact: '',
        rentAmount: 0,
        rentCadence: 'weekly',
        bondWeeks: 4,
        advanceWeeks: 2,
        maxOccupants: 4,
        setupComplete: false,
      );

  static List<User> users() => [];
  static List<Invite> invites() => [];
  static List<HouseRule> rules() => [];
  static List<Bill> bills() => [];
  static List<BillSchedule> schedules() => [];
  static List<Subscription> subscriptions() => [];
  static List<Necessity> necessities() => [];
  static List<Grocery> groceries() => [];
  static List<CleaningRosterEntry> roster() => [];
  static List<CleaningTask> tasks() => [];
  static List<Party> parties() => [];
  static Messages messages() => Messages(group: [], dms: {});
  static List<Complaint> complaints() => [];
  static List<Issue> issues() => [];
}
