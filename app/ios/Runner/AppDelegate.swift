// AppDelegate для Kaizen Runner.
// Регистрирует MethodChannel 'kaizen/widget' → 'updateWidget' для iOS-виджета.
//
// [iOS-UNVERIFIED] — не проверено без Mac/Xcode.
// При получении 'updateWidget':
//   1. Все поля §8 WIDGET.md записываются в App Group UserDefaults
//      (suiteName: "group.com.kaizen.app").
//   2. Вызывается WidgetCenter.shared.reloadAllTimelines() для перезагрузки
//      timeline без запуска extension-процесса.
//
// Требования к Xcode-проекту:
//   - Runner target: App Groups capability включена, "group.com.kaizen.app" добавлен.
//   - KaizenWidget Extension target: та же App Group.
//   (Подробнее: docs/SETUP-ios-widget.md)

import Flutter
import UIKit
import WidgetKit   // [iOS-UNVERIFIED] WidgetKit доступен с iOS 14+

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    // Suite name App Group — должен совпадать с Provider.swift в KaizenWidget extension.
    private let kAppGroupSuiteName = "group.com.kaizen.app"
    private let kChannelName       = "kaizen/widget"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        // MethodChannel регистрируется после инициализации FlutterEngine.
        return result
    }

    // [iOS-UNVERIFIED] FlutterImplicitEngineBridge вызывается после инициализации движка.
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        // Регистрируем обработчик MethodChannel для виджета.
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        let channel = FlutterMethodChannel(
            name: kChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            if call.method == "updateWidget" {
                self.handleUpdateWidget(call: call, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Обработчик 'updateWidget'

    // [iOS-UNVERIFIED] Записывает поля §8 WIDGET.md в App Group UserDefaults,
    // затем просит WidgetKit перезагрузить все timelines.
    private func handleUpdateWidget(call: FlutterMethodCall, result: FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let ud = UserDefaults(suiteName: kAppGroupSuiteName)
        else {
            result(FlutterError(
                code: "WIDGET_ERROR",
                message: "App Group UserDefaults not available: \(kAppGroupSuiteName)",
                details: nil
            ))
            return
        }

        // Записываем все поля из payload §8 WIDGET.md.
        // Тип каждого поля зафиксирован в dart/widget_service.dart:
        //   String-поля: next_items, streak, kai_emotion, theme_*, last_opened_at, main_progress
        //   Int-поля:    main_done, main_total, is_harsh (0/1)

        let stringKeys = [
            "next_items", "streak", "kai_emotion",
            "theme_accent", "theme_bg", "theme_surface", "theme_text", "theme_text_muted",
            "last_opened_at", "main_progress",
        ]
        for key in stringKeys {
            if let val = args[key] as? String {
                ud.set(val, forKey: key)
            }
        }

        let intKeys = ["main_done", "main_total", "is_harsh"]
        for key in intKeys {
            if let val = args[key] as? Int {
                ud.set(val, forKey: key)
            }
        }

        ud.synchronize()

        // Перезагружаем timeline виджета — без этого WidgetKit не увидит новые данные.
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }

        result(nil) // успех
    }
}
