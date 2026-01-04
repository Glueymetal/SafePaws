class ImageLocation {
  final String id;
  final String name;
  final double x; // normalized [0,1]
  final double y; // normalized [0,1]

  ImageLocation({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
  });
}
