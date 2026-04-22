class Ride {
  final String id;
  final String vehicleType; // 'cab', 'auto', 'bike'
  final String pickupLocation;
  final String dropLocation;
  final double distance; // in km
  final double price;
  final DateTime bookingTime;

  Ride({
    required this.id,
    required this.vehicleType,
    required this.pickupLocation,
    required this.dropLocation,
    required this.distance,
    required this.price,
    required this.bookingTime,
  });

  String get vehicleIcon {
    switch (vehicleType.toLowerCase()) {
      case 'cab':
        return '🚗';
      case 'auto':
        return '🛺';
      case 'bike':
        return '🏍️';
      default:
        return '🚗';
    }
  }

  String get vehicleName {
    switch (vehicleType.toLowerCase()) {
      case 'cab':
        return 'Cab';
      case 'auto':
        return 'Auto';
      case 'bike':
        return 'Bike';
      default:
        return 'Vehicle';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleType': vehicleType,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'distance': distance,
      'price': price,
      'bookingTime': bookingTime.toIso8601String(),
    };
  }

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'],
      vehicleType: json['vehicleType'],
      pickupLocation: json['pickupLocation'],
      dropLocation: json['dropLocation'],
      distance: json['distance'].toDouble(),
      price: json['price'].toDouble(),
      bookingTime: DateTime.parse(json['bookingTime']),
    );
  }

  // Calculate price based on vehicle type and distance
  static double calculatePrice(String vehicleType, double distance) {
    switch (vehicleType.toLowerCase()) {
      case 'bike':
        return (distance * 8) + 20; // ₹8/km + ₹20 base fare
      case 'auto':
        return (distance * 12) + 30; // ₹12/km + ₹30 base fare
      case 'cab':
        return (distance * 18) + 50; // ₹18/km + ₹50 base fare
      default:
        return distance * 15;
    }
  }
}
