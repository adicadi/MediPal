import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyService {
  static const Map<String, String> emergencyNumbers = {
    'US': '911',
    'UK': '999',
    'EU': '112',
    'AU': '000',
    'IN': '102',
  };

  static Future<void> callEmergency() async {
    final countryCode = await _getCountryCode();
    final number = emergencyNumbers[countryCode] ?? '911';
    final uri = Uri.parse('tel:$number');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> openTelehealthService() async {
    // Integration with telehealth providers
    const telehealthUrl = 'https://www.teladoc.com'; // Example
    final uri = Uri.parse(telehealthUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<String> _getCountryCode() async {
    // Implement location-based country detection
    try {
      Position position = await Geolocator.getCurrentPosition();
      // Use reverse geocoding to get country code
      return 'US'; // Placeholder
    } catch (e) {
      return 'US'; // Default
    }
  }
}
