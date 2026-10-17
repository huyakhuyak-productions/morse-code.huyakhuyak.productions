import Observation
import SwiftUI

/// What the tone engine is doing right now, for the views that light up with it.
@MainActor @Observable
final class LampState {
    /// A tone is sounding.
    var isLit = false
    /// During playback, the element whose tone is sounding.
    var litElementIndex: Int?
    /// Output volume is zero; the drills say "Sound is off".
    var isMuted = false
    /// Audio routes over Bluetooth; latency is out of spec and the drills say so.
    var routeIsBluetooth = false
}
