class ImageEntity {
  final String thumb;
  final String small;
  final String large;
  final bool isPending;

  const ImageEntity({
    required this.thumb,
    required this.small,
    required this.large,
    this.isPending = false,
  });

  factory ImageEntity.fromJson(Map<String, dynamic> json) => ImageEntity(
        thumb: json['thumb'] as String,
        small: json['small'] as String,
        large: json['large'] as String,
        isPending: json['isPending'] as bool? ?? false,
      );
}
