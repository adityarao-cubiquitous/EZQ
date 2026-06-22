class MenuDocument {
  const MenuDocument({
    required this.restaurantName,
    required this.branchName,
    required this.pdfUrl,
    required this.previewImageUrl,
  });

  final String restaurantName;
  final String branchName;
  final String? pdfUrl;
  final String? previewImageUrl;

  bool get hasPdf => pdfUrl != null && pdfUrl!.trim().isNotEmpty;
  bool get hasPreview =>
      previewImageUrl != null && previewImageUrl!.trim().isNotEmpty;
}
