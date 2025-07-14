class PaginatedResponse<T> {
  final List<T> data;
  final int totalCount;
  
  PaginatedResponse({
    required this.data,
    required this.totalCount,
  });
}