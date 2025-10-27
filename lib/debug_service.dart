import 'package:logger/logger.dart';

class DebugService {
  static final DebugService _instance = DebugService._internal();
  factory DebugService() => _instance;
  DebugService._internal();

  late final Logger _logger;

  void initialize({bool enableColors = true, Level logLevel = Level.debug}) {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: enableColors,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      level: logLevel,
    );
  }

  // Legacy method for backward compatibility
  void log(String message) {
    debug(message);
  }

  // Debug level - detailed information for debugging
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  // Info level - general information
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  // Warning level - potentially harmful situations
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  // Error level - error events that might still allow the app to continue
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  // Fatal level - very severe error events that will presumably lead the app to abort
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  // Bluetooth specific logging methods
  void bluetoothDebug(String message, [dynamic error, StackTrace? stackTrace]) {
    debug('[BLUETOOTH] $message', error, stackTrace);
  }

  void bluetoothError(String message, [dynamic error, StackTrace? stackTrace]) {
    error('[BLUETOOTH] $message', error, stackTrace);
  }

  void bluetoothInfo(String message, [dynamic error, StackTrace? stackTrace]) {
    info('[BLUETOOTH] $message', error, stackTrace);
  }
}
