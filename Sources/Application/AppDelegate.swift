// Copyright © 2020 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import SwiftWin32
import Foundation
import WinSDK

private extension View {
  func addSubviews(_ views: [View]) {
    _ = views.map { self.addSubview($0) }
  }
}

private extension Button {
  convenience init(frame: Rect = .zero, title: String) {
    self.init(frame: frame)
    setTitle(title, forState: .normal)
  }
}

private enum CalculatorOperation {
case undefined
case addition
case substraction
case multiplication
case division
}

private struct CalculatorState {
  var lhs: NSDecimalNumber = .zero
  var rhs: NSDecimalNumber = .zero
  var operand: WritableKeyPath<Self, NSDecimalNumber> = \.lhs
  var operation: CalculatorOperation = .undefined {
    willSet { self.operand = (newValue == .undefined) ? \.lhs : \.rhs }
  }

  mutating func evaluate() -> NSDecimalNumber {
    switch self.operation {
    case .undefined:      break
    case .addition:       lhs = lhs.adding(rhs)
    case .substraction:   lhs = lhs.subtracting(rhs)
    case .multiplication: lhs = lhs.multiplying(by: rhs)
    case .division:       lhs = lhs.dividing(by: rhs)
    }

    rhs = .zero
    operation = .undefined

    return lhs
  }
}

private class App {
  private var state: CalculatorState = CalculatorState()

  private var window: Window

  private var txtResult: TextField = {
    let txtResult = TextField(frame: Rect(x: 34, y: 32, width: 128, height: 24))
    txtResult.font = Font(name: "Consolas", size: Font.systemFontSize)
    txtResult.textAlignment = .right
    txtResult.text = "0"
    return txtResult
  }()

  private var btnDigits: [Button] = [
      Button(frame: Rect(x: 32, y: 192, width: 64, height: 32), title: "0"),
      Button(frame: Rect(x: 32, y: 160, width: 32, height: 32), title: "1"),
      Button(frame: Rect(x: 64, y: 160, width: 32, height: 32), title: "2"),
      Button(frame: Rect(x: 96, y: 160, width: 32, height: 32), title: "3"),
      Button(frame: Rect(x: 32, y: 128, width: 32, height: 32), title: "4"),
      Button(frame: Rect(x: 64, y: 128, width: 32, height: 32), title: "5"),
      Button(frame: Rect(x: 96, y: 128, width: 32, height: 32), title: "6"),
      Button(frame: Rect(x: 32, y: 96, width: 32, height: 32), title: "7"),
      Button(frame: Rect(x: 64, y: 96, width: 32, height: 32), title: "8"),
      Button(frame: Rect(x: 96, y: 96, width: 32, height: 32), title: "9"),
  ]

  private var btnDecimal: Button =
      Button(frame: Rect(x: 96, y: 192, width: 32, height: 32), title: ".")

  private var btnOperations: [Button] = [
      Button(frame: Rect(x: 32, y: 64, width: 32, height: 32), title: "AC"),
      Button(frame: Rect(x: 64, y: 64, width: 32, height: 32), title: "⁺∕₋"),
      Button(frame: Rect(x: 96, y: 64, width: 32, height: 32), title: "%"),
      Button(frame: Rect(x: 128, y: 64, width: 32, height: 32), title: "÷"),
      Button(frame: Rect(x: 128, y: 96, width: 32, height: 32), title: "x"),
      Button(frame: Rect(x: 128, y: 128, width: 32, height: 32), title: "-"),
      Button(frame: Rect(x: 128, y: 160, width: 32, height: 32), title: "+"),
      Button(frame: Rect(x: 128, y: 192, width: 32, height: 32), title: "="),
  ]

  public init(windowScene: WindowScene) {
    self.window = Window(windowScene: windowScene)

    self.window.rootViewController = ViewController()
    self.window.rootViewController?.title = "Calculator"

    // Update Theme
    
    let handle = self.window.handle

    var light_mode = 0;
    var light_mode_size = UInt32(MemoryLayout<Int>.size)
    
    var kGetPreferredBrightnessRegKey = UInt16("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize");
    var kGetPreferredBrightnessRegValue = UInt16("AppsUseLightTheme");

    let result = RegGetValueA(HKEY_CURRENT_USER, &kGetPreferredBrightnessRegKey,
                               &kGetPreferredBrightnessRegValue,
                               UInt32(RRF_RT_REG_DWORD), nil, &light_mode,
                               &light_mode_size)

      var enable_dark_mode = light_mode == 0 ? 1 : 0;
      DwmSetWindowAttribute(handle, UInt32(DWMWA_USE_IMMERSIVE_DARK_MODE.rawValue),
                            &enable_dark_mode, light_mode_size)
                          
    self.window.backgroundColor = Color(white: 0, alpha: 0)

    let gwl_style = GetWindowLongW(handle, GWL_STYLE)

    SetWindowLongW(handle,
      GWL_STYLE,
      gwl_style
        | Int32(WS_OVERLAPPEDWINDOW)
        | WS_THICKFRAME)

    // var enable = true
    var dark_bool = enable_dark_mode;
    var margins = MARGINS()
    margins.cyTopHeight = -1
    // margins.cxLeftWidth = -1
    // margins.cxRightWidth = -1
    // margins.cyBottomHeight = -1

    DwmExtendFrameIntoClientArea(handle, &margins)

    var effect_value = 2; // MICA (on Windows 11)
    DwmSetWindowAttribute(handle, 20, &dark_bool, UInt32(MemoryLayout<Bool>.size));
    DwmSetWindowAttribute(handle, 38, &effect_value, UInt32(MemoryLayout<Int>.size));

    // End Update Theme

    self.window.addSubview(self.txtResult)
    self.txtResult.font = Font(name: "Consolas", size: Font.systemFontSize)
    self.txtResult.textAlignment = .right
    self.txtResult.text =
        self.state.evaluate().description(withLocale: Locale.current)

    self.window.addSubviews(self.btnDigits)
    self.btnDigits.forEach {
      $0.addTarget(self, action: App.onDigitPress(_:_:),
                   for: .primaryActionTriggered)
    }
    self.window.addSubviews(self.btnOperations)
    self.btnOperations.forEach {
      $0.addTarget(self, action: App.onOperationPress(_:_:),
                   for: .primaryActionTriggered)
    }
    self.window.addSubview(self.btnDecimal)
    self.btnDecimal.addTarget(self, action: App.onDecimalPress(_:_:),
                              for: .primaryActionTriggered)
                              
    self.window.subviews[0].backgroundColor = Color(white: 0, alpha: 0)

    self.window.makeKeyAndVisible()
  }

  private func onDigitPress(_ sender: Button, _: Control.Event) {
    guard let input = self.btnDigits.firstIndex(of: sender) else {
      fatalError("invalid target: \(self) for sender: \(sender)")
    }

    var operand = self.state[keyPath: self.state.operand] as Decimal
    operand *= 10
    operand += Decimal(input)
    self.state[keyPath: self.state.operand] = operand as NSDecimalNumber

    self.txtResult.text = operand.description
  }

  private func onOperationPress(_ sender: Button, _: Control.Event) {
    switch self.btnOperations.firstIndex(of: sender)! {
    case 0: /* AC */
      self.state = CalculatorState()
      self.txtResult.text = Decimal.zero.description
    case 1: /* +/- */
      var operand = self.state[keyPath: self.state.operand] as Decimal
      operand.negate()
    case 3: /* ÷ */
      self.state.operation = .division
    case 4: /* x */
      self.state.operation = .multiplication
    case 5: /* - */
      self.state.operation = .substraction
    case 6: /* + */
      self.state.operation = .addition
    case 2: /* % */
      if (self.state.lhs as Decimal).isZero { break }
      self.state.operation = .division
      self.state.rhs = NSDecimalNumber(string: "100")
      fallthrough
    case 7: /* = */
      self.txtResult.text =
          self.state.evaluate().description(withLocale: Locale.current)
    default:
      fatalError("unknown operation \(self.btnOperations.firstIndex(of: sender)!)")
    }
  }

  private func onDecimalPress(_ sender: Button, _: Control.Event) {
    self.txtResult.text =
        (self.state[keyPath: self.state.operand] as Decimal).description
  }
}

@main
final class AppScene: ApplicationDelegate, SceneDelegate {
  private var app: App?

  func scene(_ scene: Scene, willConnectTo session: SceneSession,
             options: Scene.ConnectionOptions) {
    guard let windowScene = scene as? WindowScene else { return }

    let size: Size = Size(width: 192, height: 264)
    windowScene.sizeRestrictions?.minimumSize = size
    windowScene.sizeRestrictions?.maximumSize = size

    self.app = App(windowScene: windowScene)
  }
  
  func sceneDidBecomeActive(_: Scene) {
    print("Good morning!")
  }

  func sceneWillResignActive(_: Scene) {
    print("Good night!")
  }

  func applicationWillTerminate(_: Application) {
    print("Goodbye cruel world!")
  }
}
