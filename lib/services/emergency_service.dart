import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class EmergencyNumbers {
  final String emergency;
  final String police;
  final String fire;
  final String ambulance;
  final String poisonControl;
  final String mentalHealth;
  final String domesticViolence;
  final String countryName;
  final String countryCode;

  const EmergencyNumbers({
    required this.emergency,
    required this.police,
    required this.fire,
    required this.ambulance,
    required this.poisonControl,
    required this.mentalHealth,
    required this.domesticViolence,
    required this.countryName,
    required this.countryCode,
  });

  String get primaryEmergencyNumber {
    final RegExp numberRegex = RegExp(r'\d{3,4}');
    final match = numberRegex.firstMatch(emergency);
    return match?.group(0) ?? '112';
  }

  Map<String, dynamic> toMap() {
    return {
      'emergency': emergency,
      'police': police,
      'fire': fire,
      'ambulance': ambulance,
      'poisonControl': poisonControl,
      'mentalHealth': mentalHealth,
      'domesticViolence': domesticViolence,
      'countryName': countryName,
      'countryCode': countryCode,
    };
  }

  factory EmergencyNumbers.fromMap(Map<String, dynamic> map) {
    return EmergencyNumbers(
      emergency: map['emergency'] ?? '',
      police: map['police'] ?? '',
      fire: map['fire'] ?? '',
      ambulance: map['ambulance'] ?? '',
      poisonControl: map['poisonControl'] ?? '',
      mentalHealth: map['mentalHealth'] ?? '',
      domesticViolence: map['domesticViolence'] ?? '',
      countryName: map['countryName'] ?? '',
      countryCode: map['countryCode'] ?? '',
    );
  }
}

class EmergencyService {
  static Position? _lastKnownPosition;
  static String? _lastKnownCountry;
  static EmergencyNumbers? _cachedNumbers;
  static DateTime? _lastLocationUpdate;

  // Cache validity duration (6 hours - longer since we can't do reverse geocoding easily)
  static const Duration _cacheValidityDuration = Duration(hours: 6);

  // Comprehensive emergency numbers database with coordinates for major countries
  static const Map<String, EmergencyNumbers> _emergencyDatabase = {
    'US': EmergencyNumbers(
      emergency: '911',
      police: '911',
      fire: '911',
      ambulance: '911',
      poisonControl: '1-800-222-1222',
      mentalHealth: '988',
      domesticViolence: '1-800-799-7233',
      countryName: 'United States',
      countryCode: 'US',
    ),
    'CA': EmergencyNumbers(
      emergency: '911',
      police: '911',
      fire: '911',
      ambulance: '911',
      poisonControl: '1-844-764-7669',
      mentalHealth: '1-833-456-4566',
      domesticViolence: '1-800-668-6868',
      countryName: 'Canada',
      countryCode: 'CA',
    ),
    'GB': EmergencyNumbers(
      emergency: '999',
      police: '999',
      fire: '999',
      ambulance: '999',
      poisonControl: '111',
      mentalHealth: '116 123',
      domesticViolence: '0808 2000 247',
      countryName: 'United Kingdom',
      countryCode: 'GB',
    ),
    'DE': EmergencyNumbers(
      emergency: '112',
      police: '110',
      fire: '112',
      ambulance: '112',
      poisonControl: '030 19240',
      mentalHealth: '0800 111 0 111',
      domesticViolence: '08000 116 016',
      countryName: 'Germany',
      countryCode: 'DE',
    ),
    'FR': EmergencyNumbers(
      emergency: '112',
      police: '17',
      fire: '18',
      ambulance: '15',
      poisonControl: '01 40 05 48 48',
      mentalHealth: '3114',
      domesticViolence: '3919',
      countryName: 'France',
      countryCode: 'FR',
    ),
    'IT': EmergencyNumbers(
      emergency: '112',
      police: '113',
      fire: '115',
      ambulance: '118',
      poisonControl: '06 3054343',
      mentalHealth: '800 833 833',
      domesticViolence: '1522',
      countryName: 'Italy',
      countryCode: 'IT',
    ),
    'ES': EmergencyNumbers(
      emergency: '112',
      police: '091',
      fire: '080',
      ambulance: '112',
      poisonControl: '91 562 04 20',
      mentalHealth: '717 003 717',
      domesticViolence: '016',
      countryName: 'Spain',
      countryCode: 'ES',
    ),
    'AU': EmergencyNumbers(
      emergency: '000',
      police: '000',
      fire: '000',
      ambulance: '000',
      poisonControl: '13 11 26',
      mentalHealth: '13 11 14',
      domesticViolence: '1800 737 732',
      countryName: 'Australia',
      countryCode: 'AU',
    ),
    'NZ': EmergencyNumbers(
      emergency: '111',
      police: '111',
      fire: '111',
      ambulance: '111',
      poisonControl: '0800 764 766',
      mentalHealth: '1737',
      domesticViolence: '0800 456 450',
      countryName: 'New Zealand',
      countryCode: 'NZ',
    ),
    'JP': EmergencyNumbers(
      emergency: '110',
      police: '110',
      fire: '119',
      ambulance: '119',
      poisonControl: '072-727-2499',
      mentalHealth: '0570-064-556',
      domesticViolence: '0570-0-55210',
      countryName: 'Japan',
      countryCode: 'JP',
    ),
    'IN': EmergencyNumbers(
      emergency: '112',
      police: '100',
      fire: '101',
      ambulance: '108',
      poisonControl: '1066',
      mentalHealth: '9152987821',
      domesticViolence: '181',
      countryName: 'India',
      countryCode: 'IN',
    ),
    'BR': EmergencyNumbers(
      emergency: '190',
      police: '190',
      fire: '193',
      ambulance: '192',
      poisonControl: '0800 722 6001',
      mentalHealth: '188',
      domesticViolence: '180',
      countryName: 'Brazil',
      countryCode: 'BR',
    ),
    'MX': EmergencyNumbers(
      emergency: '911',
      police: '911',
      fire: '911',
      ambulance: '911',
      poisonControl: '800 472 3690',
      mentalHealth: '800 290 0024',
      domesticViolence: '911',
      countryName: 'Mexico',
      countryCode: 'MX',
    ),
    'ZA': EmergencyNumbers(
      emergency: '10111',
      police: '10111',
      fire: '10177',
      ambulance: '10177',
      poisonControl: '086 155 5777',
      mentalHealth: '0800 567 567',
      domesticViolence: '0800 150 150',
      countryName: 'South Africa',
      countryCode: 'ZA',
    ),
  };

  // Geographic regions with approximate boundaries for country detection
  static const Map<String, Map<String, dynamic>> _geographicRegions = {
    'US': {
      'bounds': {
        'north': 49.3457868,
        'south': 24.7433195,
        'west': -124.7844079,
        'east': -66.9513812
      }
    },
    'CA': {
      'bounds': {
        'north': 83.6381,
        'south': 41.6765559,
        'west': -141.00187,
        'east': -52.6480987
      }
    },
    'GB': {
      'bounds': {
        'north': 60.8445,
        'south': 49.8625,
        'west': -8.6493,
        'east': 1.7629
      }
    },
    'DE': {
      'bounds': {
        'north': 55.0815,
        'south': 47.2701,
        'west': 5.8663,
        'east': 15.0419
      }
    },
    'FR': {
      'bounds': {
        'north': 51.1242,
        'south': 41.3253,
        'west': -5.5591,
        'east': 9.6625
      }
    },
    'IT': {
      'bounds': {
        'north': 47.0921,
        'south': 35.4929,
        'west': 6.6267,
        'east': 18.7975
      }
    },
    'ES': {
      'bounds': {
        'north': 43.7486,
        'south': 27.6362,
        'west': -18.1614,
        'east': 4.3262
      }
    },
    'AU': {
      'bounds': {
        'north': -9.0882,
        'south': -54.7772,
        'west': 72.2460,
        'east': 168.2249
      }
    },
    'NZ': {
      'bounds': {
        'north': -29.2313,
        'south': -52.6194,
        'west': 165.8694,
        'east': -175.8316
      }
    },
    'JP': {
      'bounds': {
        'north': 45.7112,
        'south': 20.2145,
        'west': 122.7141,
        'east': 154.205
      }
    },
    'IN': {
      'bounds': {
        'north': 37.6,
        'south': 6.4627,
        'west': 68.1097,
        'east': 97.395
      }
    },
    'BR': {
      'bounds': {
        'north': 5.2842,
        'south': -34.0891,
        'west': -73.9872,
        'east': -28.6341
      }
    },
    'MX': {
      'bounds': {
        'north': 32.7187,
        'south': 14.3895,
        'west': -118.4662,
        'east': -86.7104
      }
    },
    'ZA': {
      'bounds': {
        'north': -22.1265,
        'south': -47.1313,
        'west': 16.2335,
        'east': 32.8707
      }
    },
  };

  // Default emergency numbers (International/Generic)
  static const EmergencyNumbers _defaultNumbers = EmergencyNumbers(
    emergency: '112',
    police: '112',
    fire: '112',
    ambulance: '112',
    poisonControl: 'Contact local emergency services',
    mentalHealth: 'Contact local mental health services',
    domesticViolence: 'Contact local domestic violence hotline',
    countryName: 'International',
    countryCode: 'INTL',
  );

  /// Get current location-based emergency numbers using geographic approximation
  static Future<EmergencyNumbers> getEmergencyNumbers() async {
    try {
      // Check if cached numbers are still valid
      if (_cachedNumbers != null &&
          _lastKnownCountry != null &&
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!) <
              _cacheValidityDuration) {
        print(
            '📍 Using cached emergency numbers for ${_cachedNumbers!.countryName}');
        return _cachedNumbers!;
      }

      // Check location permission using only Geolocator
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print(
              '📍 Location permission denied, using default emergency numbers');
          return _defaultNumbers;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print(
            '📍 Location permission permanently denied, using default emergency numbers');
        return _defaultNumbers;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('📍 Location services disabled, using default emergency numbers');
        return _defaultNumbers;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );

      _lastKnownPosition = position;
      _lastLocationUpdate = DateTime.now();

      // Use geographic approximation to determine country
      final country = _approximateCountryFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (country != null) {
        _lastKnownCountry = country;
        if (_emergencyDatabase.containsKey(country)) {
          _cachedNumbers = _emergencyDatabase[country]!;
          print(
              '📍 Located in approximately ${_cachedNumbers!.countryName}, using local emergency numbers');
          return _cachedNumbers!;
        }
      }

      print(
          '📍 Could not determine country from coordinates, using default emergency numbers');
      return _defaultNumbers;
    } catch (e) {
      print('❌ Error getting location-based emergency numbers: $e');

      // Try to determine country by platform locale as fallback
      final countryFromLocale = _getCountryFromPlatformLocale();
      if (countryFromLocale != null &&
          _emergencyDatabase.containsKey(countryFromLocale)) {
        _cachedNumbers = _emergencyDatabase[countryFromLocale]!;
        print(
            '📍 Using emergency numbers based on device locale: ${_cachedNumbers!.countryName}');
        return _cachedNumbers!;
      }

      return _defaultNumbers;
    }
  }

  /// Approximate country detection using geographic boundaries
  static String? _approximateCountryFromCoordinates(
      double latitude, double longitude) {
    for (final entry in _geographicRegions.entries) {
      final countryCode = entry.key;
      final bounds = entry.value['bounds'] as Map<String, dynamic>;

      final north = bounds['north'] as double;
      final south = bounds['south'] as double;
      final west = bounds['west'] as double;
      final east = bounds['east'] as double;

      // Handle longitude wrap-around (e.g., for countries crossing 180°)
      bool inLongitudeRange;
      if (west > east) {
        // Country crosses the 180° meridian
        inLongitudeRange = longitude >= west || longitude <= east;
      } else {
        inLongitudeRange = longitude >= west && longitude <= east;
      }

      if (latitude >= south && latitude <= north && inLongitudeRange) {
        return countryCode;
      }
    }

    return null;
  }

  /// Get country from platform locale as fallback
  static String? _getCountryFromPlatformLocale() {
    try {
      // This is a simplified approach - in a real app you might use
      // more sophisticated locale detection
      if (Platform.isAndroid || Platform.isIOS) {
        // Could potentially read from system locale in the future
        // For now, return null to use default
        return null;
      }
    } catch (e) {
      print('❌ Error getting platform locale: $e');
    }
    return null;
  }

  /// Call emergency number with proper URL launching
  static Future<bool> callEmergency() async {
    try {
      final emergencyNumbers = await getEmergencyNumbers();
      return await callSpecificNumber(emergencyNumbers.primaryEmergencyNumber);
    } catch (e) {
      print('❌ Error calling emergency: $e');
      // Fallback: try calling generic emergency numbers
      return await callSpecificNumber('112') || await callSpecificNumber('911');
    }
  }

  /// Call a specific emergency number
  static Future<bool> callSpecificNumber(String number) async {
    try {
      // Clean the number for calling (remove non-digit characters except +)
      final cleanNumber = number.replaceAll(RegExp(r'[^\d\+]'), '');

      if (cleanNumber.isNotEmpty) {
        final uri = Uri.parse('tel:$cleanNumber');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return true;
        } else {
          print('❌ Cannot launch phone dialer for $cleanNumber');
        }
      }
    } catch (e) {
      print('❌ Error calling $number: $e');
    }
    return false;
  }

  /// Open telehealth service
  static Future<bool> openTelehealthService() async {
    try {
      const telehealthUrl = 'https://www.teladoc.com/';
      final uri = Uri.parse(telehealthUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error opening telehealth service: $e');
      return false;
    }
  }

  /// Check basic location permissions
  static Future<Map<String, bool>> checkAllPermissions() async {
    final results = <String, bool>{};

    try {
      // Location permission using Geolocator only
      final geoPermission = await Geolocator.checkPermission();
      results['location'] = geoPermission == LocationPermission.always ||
          geoPermission == LocationPermission.whileInUse;

      // Assume phone calling is available (most devices support this)
      results['phone'] = true;

      // Location services
      results['location_service'] = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('❌ Error checking permissions: $e');
      results['location'] = false;
      results['phone'] = true;
      results['location_service'] = false;
    }

    return results;
  }

  /// Request location permission
  static Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    try {
      final permission = await Geolocator.requestPermission();

      results['location'] = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      results['phone'] = true; // Assume phone calling is available
      results['location_service'] = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      results['location'] = false;
      results['phone'] = true;
      results['location_service'] = false;
    }

    return results;
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('❌ Error checking location service: $e');
      return false;
    }
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      print('❌ Error opening location settings: $e');
      return false;
    }
  }

  /// Open app settings (simplified version)
  static Future<bool> openAppSettings() async {
    try {
      // For now, just open location settings as that's the main permission we need
      return await openLocationSettings();
    } catch (e) {
      print('❌ Error opening app settings: $e');
      return false;
    }
  }

  /// Get emergency numbers for a specific country code
  static EmergencyNumbers getEmergencyNumbersForCountry(String countryCode) {
    return _emergencyDatabase[countryCode.toUpperCase()] ?? _defaultNumbers;
  }

  /// Get all available countries
  static List<String> getAvailableCountries() {
    return _emergencyDatabase.keys.toList()..sort();
  }

  /// Get countries with their display names
  static List<Map<String, String>> getAvailableCountriesWithNames() {
    return _emergencyDatabase.entries
        .map((entry) => {
              'code': entry.key,
              'name': entry.value.countryName,
              'emergency': entry.value.emergency,
            })
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  /// Clear cached location data
  static void clearCache() {
    _lastKnownPosition = null;
    _lastKnownCountry = null;
    _cachedNumbers = null;
    _lastLocationUpdate = null;
    print('📍 Emergency service cache cleared');
  }

  /// Force refresh location and emergency numbers
  static Future<EmergencyNumbers> refreshEmergencyNumbers() async {
    clearCache();
    return await getEmergencyNumbers();
  }

  /// Get last known location info
  static Map<String, dynamic> getLocationInfo() {
    return {
      'hasLocation': _lastKnownPosition != null,
      'country': _lastKnownCountry,
      'countryName': _cachedNumbers?.countryName,
      'latitude': _lastKnownPosition?.latitude,
      'longitude': _lastKnownPosition?.longitude,
      'accuracy': _lastKnownPosition?.accuracy,
      'lastUpdate': _lastLocationUpdate?.toIso8601String(),
      'cacheValid': _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!) <
              _cacheValidityDuration,
      'detection_method': 'geographic_approximation',
    };
  }

  /// Test basic functionality
  static Future<Map<String, dynamic>> testEmergencyFunctionality() async {
    final results = <String, dynamic>{};

    try {
      // Test location access
      results['location_test'] = await _testLocationAccess();

      // Test permissions
      results['permissions'] = await checkAllPermissions();

      // Test emergency number retrieval
      final emergencyNumbers = await getEmergencyNumbers();
      results['emergency_numbers'] = {
        'country': emergencyNumbers.countryName,
        'primary': emergencyNumbers.emergency,
        'detection_method': 'simplified_geographic',
      };

      // Test URL launching capability (without actually calling)
      final canCall = await canLaunchUrl(Uri.parse('tel:112'));
      results['can_make_calls'] = canCall;

      results['overall_status'] = 'success';
    } catch (e) {
      results['error'] = e.toString();
      results['overall_status'] = 'failed';
    }

    return results;
  }

  static Future<Map<String, dynamic>> _testLocationAccess() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'success': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get manual country selection options for user
  static Future<EmergencyNumbers> selectCountryManually(
      String countryCode) async {
    final numbers = getEmergencyNumbersForCountry(countryCode);

    // Cache the manually selected country
    _lastKnownCountry = countryCode;
    _cachedNumbers = numbers;
    _lastLocationUpdate = DateTime.now();

    print('📍 Manually selected ${numbers.countryName} for emergency numbers');
    return numbers;
  }

  /// Get permission status information
  static Future<Map<String, dynamic>> getPermissionStatus() async {
    final permissions = await checkAllPermissions();

    return {
      'location_permission': permissions['location'] ?? false,
      'phone_permission': permissions['phone'] ?? true,
      'location_service_enabled': permissions['location_service'] ?? false,
      'has_cached_location': _lastKnownPosition != null,
      'last_known_country': _lastKnownCountry,
      'cache_age_minutes': _lastLocationUpdate != null
          ? DateTime.now().difference(_lastLocationUpdate!).inMinutes
          : null,
      'emergency_numbers_available': _cachedNumbers != null,
      'plugin_status': 'simplified_without_geocoding',
    };
  }
}
