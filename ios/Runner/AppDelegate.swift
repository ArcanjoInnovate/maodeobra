import Flutter
import UIKit
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // ✅ MANTÉM A CONFIGURAÇÃO ORIGINAL
    // FirebaseAppDelegateProxyEnabled = true faz a config automática
    
    // ✅ REGISTRA PARA NOTIFICAÇÕES (ÚNICO ACRÉSCIMO!)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          print("🔔 Permissão: \(granted)")
        }
      )
    }
    
    // ✅ ESTE É O PEDAÇO QUE FALTAVA!
    application.registerForRemoteNotifications()
    
    // ✅ Define delegate do Firebase Messaging
    Messaging.messaging().delegate = self
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // ✅ Recebe APNs token
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("🍎 APNs OK!")
    Messaging.messaging().apnsToken = deviceToken
  }
  
  // ✅ Erro APNs
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ APNs: \(error)")
  }
}

// ✅ Firebase Messaging Delegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📱 FCM: \(fcmToken ?? "nil")")
  }
}