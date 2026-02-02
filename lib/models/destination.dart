class Destination {
  final String id;
  final String address;
  final String label;
  final double latitude;
  final double longitude;
  final int stopDuration; // em minutos
  final int order;

  Destination({
    required this.id,
    required this.address,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.stopDuration,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'stopDuration': stopDuration,
      'order': order,
    };
  }

  factory Destination.fromMap(Map<String, dynamic> map) {
    return Destination(
      id: map['id'],
      address: map['address'],
      label: map['label'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      stopDuration: map['stopDuration'],
      order: map['order'] ?? 0,
    );
  }
}