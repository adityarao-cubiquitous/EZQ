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

const _customerHostingOrigin = 'https://ezq-dev-cubiquitous.web.app';

Uri? resolveCustomerMenuUri(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final parsed = Uri.tryParse(raw);
  if (parsed == null) return null;
  if (parsed.hasScheme) return parsed;
  if (raw.startsWith('//')) return Uri.parse('https:$raw');
  return Uri.parse(_customerHostingOrigin).resolve(raw);
}
