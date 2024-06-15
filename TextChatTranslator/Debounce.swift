import Foundation

class Debounce {
  private let delay: TimeInterval
  private var timer: Timer?

  init(delay: TimeInterval) {
    self.delay = delay
  }

  func call(action: @escaping () -> Void) {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
      action()
    }
  }
}
