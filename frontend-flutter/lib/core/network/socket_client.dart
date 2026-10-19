import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class SocketClient {
  static final SocketClient _instance = SocketClient._internal();
  late sio.Socket socket;

  String _driverId = '';
  String _name = '';
  String _truckIcon = '🚚';
  bool _isPremium = false;
  String _role = 'motorista';

  factory SocketClient() => _instance;

  SocketClient._internal() {
    socket = sio.io(
      AppConstants.socketUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );
    socket.onConnect((_) {
      if (_driverId.isEmpty) return;
      socket.emit('register_driver', {
        'driverId': _driverId,
        'isPremium': _isPremium,
        'role': _role,
      });
      if (_name.isNotEmpty) {
        socket.emit('join_truck_network', {
          'driverId': _driverId,
          'name': _name,
          'truckIcon': _truckIcon,
          'role': _role,
        });
      }
    });
  }

  bool get isConnected => socket.connected;

  void connectToServer({
    required String driverId,
    required bool isPremium,
    String name = '',
    String truckIcon = '🚚',
  }) {
    _driverId = driverId;
    _isPremium = isPremium;
    _truckIcon = truckIcon;
    if (name.isNotEmpty) _name = name;
    if (!socket.connected) socket.connect();
  }

  void joinTruckNetwork({
    required String driverId,
    required String name,
    String truckIcon = '🚚',
    String role = 'motorista',
  }) {
    _driverId = driverId;
    _name = name;
    _truckIcon = truckIcon;
    _role = role;
    if (socket.connected) {
      socket.emit('join_truck_network', {
        'driverId': driverId,
        'name': name,
        'truckIcon': truckIcon,
        'role': role,
      });
    }
  }

  void onConnectionChange(void Function(bool connected) callback) {
    socket.onConnect((_) => callback(true));
    socket.onDisconnect((_) => callback(false));
  }


  void sendLocationUpdate({
    required double lat,
    required double lon,
    required String driverId,
    double speedKmh = 0,
  }) {
    if (socket.connected) {
      socket.emit('update_position', {
        'lat': lat,
        'lon': lon,
        'driverId': driverId,
        'speedKmh': speedKmh,
      });
    }
  }

  void sharePlace({
    required String fromDriverId,
    required String fromName,
    required String label,
    required double lat,
    required double lon,
    String type = 'endereco',
    String? targetDriverId,
  }) {
    if (!socket.connected) return;
    socket.emit('share_place', {
      'fromDriverId': fromDriverId,
      'fromName': fromName,
      'label': label,
      'type': type,
      'lat': lat,
      'lon': lon,
      if (targetDriverId != null) 'targetDriverId': targetDriverId,
    });
  }

  void onReceiveSharedPlace(void Function(dynamic data) callback) {
    socket.on('receive_shared_place', (data) => callback(data));
  }

  void sendRoadAlert({
    required String driverId,
    required String type,
    String? message,
    double? maxHeight,
    double? maxWeight,
    required double lat,
    required double lon,
  }) {
    if (!socket.connected) return;
    socket.emit('send_road_alert', {
      'driverId': driverId,
      'type': type,
      'message': message ?? '',
      'maxHeight': maxHeight,
      'maxWeight': maxWeight,
      'lat': lat,
      'lon': lon,
    });
  }

  void sendChatMessage({
    required String driverId,
    required String driverName,
    required String message,
    required double lat,
    required double lon,
    String? targetDriverId,
  }) {
    if (!socket.connected) return;
    socket.emit('broadcast_chat_message', {
      'driverId': driverId,
      'driverName': driverName,
      'message': message,
      'lat': lat,
      'lon': lon,
      if (targetDriverId != null) 'targetDriverId': targetDriverId,
    });
  }

  void sendPeerAlert({
    required String fromDriverId,
    required String fromName,
    required String targetDriverId,
    required String kind,
    String? message,
  }) {
    if (!socket.connected) return;
    socket.emit('send_peer_alert', {
      'fromDriverId': fromDriverId,
      'fromName': fromName,
      'targetDriverId': targetDriverId,
      'kind': kind,
      'message': message ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void onReceivePeerAlert(void Function(dynamic data) callback) {
    socket.on('receive_peer_alert', callback);
  }

  void shareRoute({
    required String fromDriverId,
    required String fromName,
    required String routeJson,
    String? targetDriverId,
  }) {
    if (!socket.connected) return;
    socket.emit('share_route', {
      'fromDriverId': fromDriverId,
      'fromName': fromName,
      'routeJson': routeJson,
      if (targetDriverId != null) 'targetDriverId': targetDriverId,
    });
  }

  void onReceiveSharedRoute(void Function(dynamic data) callback) {
    socket.on('receive_shared_route', callback);
  }

  void sendTruckReaction({
    required String fromName,
    required String targetDriverId,
    required String emoji,
  }) {
    if (!socket.connected) return;
    socket.emit('send_truck_reaction', {
      'fromName': fromName,
      'targetDriverId': targetDriverId,
      'emoji': emoji,
    });
  }

  void onRoadValidationAlerts(void Function(dynamic data) callback) {
    socket.on('road_validation_alerts', callback);
  }

  void onReceiveAlertRealtime(void Function(dynamic data) callback) {
    socket.on('receive_alert_realtime', callback);
  }

  void onTrucksRadarUpdate(void Function(dynamic data) callback) {
    socket.on('trucks_radar_update', callback);
  }

  void onReceiveChatMessage(void Function(dynamic data) callback) {
    socket.on('receive_chat_message', callback);
  }

  void onReceiveTruckReaction(void Function(dynamic data) callback) {
    socket.on('receive_truck_reaction', callback);
  }

  void disconnect() {
    if (socket.connected) socket.disconnect();
  }
}
