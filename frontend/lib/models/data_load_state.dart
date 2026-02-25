enum DataStatus { loading, data, degraded, error }

class DataLoadState<T> {
  final DataStatus status;
  final T? data;
  final String? message;

  const DataLoadState._({required this.status, this.data, this.message});

  factory DataLoadState.data(T data, {String? message}) {
    return DataLoadState._(
      status: DataStatus.data,
      data: data,
      message: message,
    );
  }

  factory DataLoadState.degraded(T? data, {String? message}) {
    return DataLoadState._(
      status: DataStatus.degraded,
      data: data,
      message: message,
    );
  }

  factory DataLoadState.error(String message, {T? fallbackData}) {
    return DataLoadState._(
      status: DataStatus.error,
      data: fallbackData,
      message: message,
    );
  }

  bool get isData => status == DataStatus.data;
  bool get isDegraded => status == DataStatus.degraded;
  bool get isError => status == DataStatus.error;
}
