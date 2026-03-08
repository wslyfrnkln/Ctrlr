import SwiftUI

// CABTMIDICentralViewController is unavailable in the iOS Simulator.
// All usage is gated behind a compile-time #if — not a runtime check.

#if !targetEnvironment(simulator)
import CoreAudioKit

// MARK: - BluetoothMIDIView

/// SwiftUI wrapper for CABTMIDICentralViewController.
/// Present as a sheet to let the user discover and pair BLE MIDI devices.
/// Once paired, CoreMIDI automatically registers the device as a standard
/// MIDI endpoint — no CoreBluetooth data layer required.
struct BluetoothMIDIView: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> BTMIDICentralViewController {
        BTMIDICentralViewController()
    }

    func updateUIViewController(_ uiViewController: BTMIDICentralViewController, context: Context) {}
}

/// Subclass to inject a Done button — CABTMIDICentralViewController has no
/// built-in dismiss control when presented as a sheet.
final class BTMIDICentralViewController: CABTMIDICentralViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard navigationItem.rightBarButtonItem == nil else { return }
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSelf)
        )
        title = "Bluetooth MIDI"
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

#else

// MARK: - Simulator Placeholder

struct BluetoothMIDIView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#0A84FF").opacity(0.4))
            Text("BLUETOOTH MIDI")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(.secondary)
            Text("Not available in Simulator")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0c0c0c"))
    }
}

#endif
