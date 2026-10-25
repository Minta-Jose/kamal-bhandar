import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android channels. The ids match functions/src/notify.ts.
const _channels = [
  AndroidNotificationChannel(
    'new_orders',
    'New orders',
    description: 'Loud alert when a customer places an order',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('new_order'),
  ),
  AndroidNotificationChannel('sign_ups', 'Sign-ups', description: 'New customers waiting for approval'),
  AndroidNotificationChannel('account', 'Account', description: 'Approval of your account'),
  AndroidNotificationChannel(
    'order_updates',
    'Order updates',
    description: 'Changes to your orders and pickup reminders',
    importance: Importance.high,
  ),
];

/// Registers this phone for notifications and opens the right screen on tap.
class Messaging {
  Messaging._();
  static final instance = Messaging._();

  final _local = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  String? _registeredUid;
  StreamSubscription<String>? _tokenSub;

  /// Routes from tapped notifications, e.g. "/owner/orders/abc".
  Stream<String> get taps => _taps.stream;

  Future<void> init() async {
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification')),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) _taps.add(r.payload!);
      },
    );
    final android =
        _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final c in _channels) {
      await android?.createNotificationChannel(c);
    }

    // While the app is open FCM does not show anything itself, so we do.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      final channel = m.data['channel'] as String? ?? 'order_updates';
      final c = _channels.firstWhere((x) => x.id == channel, orElse: () => _channels.last);
      _local.show(
        id: m.hashCode,
        title: n.title,
        body: n.body,
        payload: m.data['route'] as String?,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            c.id,
            c.name,
            importance: c.importance,
            priority: c.importance == Importance.max ? Priority.max : Priority.defaultPriority,
            sound: c.sound,
            icon: '@drawable/ic_notification',
          ),
        ),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_openFrom);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Let the router finish its first build before navigating.
      Future<void>.delayed(const Duration(milliseconds: 500), () => _openFrom(initial));
    }
  }

  void _openFrom(RemoteMessage m) {
    final route = m.data['route'] as String?;
    if (route != null) _taps.add(route);
  }

  // FCM registration tokens are what firebase-admin sends to today; the newer
  // installation-id API is not used until the server side supports it.
  // ignore_for_file: deprecated_member_use

  /// Saves this phone's token under users/{uid}/devices so the server can reach it.
  Future<void> register(String uid) async {
    if (_registeredUid == uid) return;
    _registeredUid = uid;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _save(uid, token);
      await _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) => _save(uid, t));
    } catch (e) {
      debugPrint('Notification setup failed: $e');
      _registeredUid = null;
    }
  }

  Future<void> _save(String uid, String token) => FirebaseFirestore.instance
      .doc('users/$uid/devices/$token')
      .set({'platform': 'android', 'updatedAt': FieldValue.serverTimestamp()});

  /// Stops notifications to this phone when signing out.
  Future<void> unregister() async {
    final uid = _registeredUid;
    _registeredUid = null;
    await _tokenSub?.cancel();
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await FirebaseFirestore.instance.doc('users/$uid/devices/$token').delete();
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Could not remove notification token: $e');
    }
  }
}
