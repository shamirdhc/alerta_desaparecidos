class PaginatedResponse<T> {
  final List<T> data;
  final int totalCount;
  final bool hasMore;

  PaginatedResponse({
    required this.data,
    required this.totalCount,
    this.hasMore = true,
  });
}