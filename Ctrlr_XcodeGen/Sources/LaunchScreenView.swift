import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.894, blue: 0.863)
                .ignoresSafeArea()

            Image("CtrlrIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .offset(y: -115)
        }
    }
}
