/// Central configuration. Replace the placeholder values before publishing.
class AppConfig {
  static const appName = 'Dragon Boat Runner';

  /// Firebase Hosting domain that serves the invite page (hosting/public).
  /// Usually `<your-firebase-project-id>.web.app`.
  static const linkHost = 'dragon-boat-runner.web.app';

  /// Custom URL scheme registered in AndroidManifest.xml and Info.plist.
  static const urlScheme = 'dragonboatrunner';

  /// Max. members per team.
  static const maxMembers = 60;

  /// Boat capacities (paddlers + drummer + steerer).
  static const smallBoatRows = 5; // 10 paddlers
  static const largeBoatRows = 10; // 20 paddlers

  /// Members can set their attendance until this long before the start.
  /// Cancelling ("no") stays possible until the start.
  static const rsvpLock = Duration(hours: 1);

  static String inviteLink(String code) => 'https://$linkHost/join/$code';
}
