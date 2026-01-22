//
//  ContentView.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

import SwiftUI
import CoreHaptics

// MARK: - THEME COLORS
extension Color {
    static let zcashGold = Color(red: 0.94, green: 0.70, blue: 0.25)
    static let darkSlate = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let neonGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
}

struct ContentView: View {
    @StateObject var zcash = ZcashEngine()
    @StateObject var bleService = BLEService()
    
    // UI State
    @State private var amount: String = ""
    @State private var dragOffset: CGSize = .zero
    @State private var isSending = false
    @State private var showReceiveMode = false
    @State private var pulseScale: CGFloat = 1.0
    
    // Haptics
    @State private var engine: CHHapticEngine?
    
    var body: some View {
        ZStack {
            // 1. Background
            Color.darkSlate.edgesIgnoringSafeArea(.all)
            
            // 2. Ambient Glow (Subtle Background Animation)
            Circle()
                .fill(Color.zcashGold.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            VStack(spacing: 0) {
                // MARK: - Header (Sync Fuel Gauge)
                // MARK: - Header (Sync Fuel Gauge)
                HStack {
                    // REPLACED: Old Text Header -> New Logo Image
                    Image("ZecerLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40) // Adjust height to fit nicely
                        .shadow(color: .zcashGold.opacity(0.6), radius: 8, x: 0, y: 0) // Glowing effect
                    
                    Spacer()
                    
                    // Sync Status Pill (Kept exactly the same)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(zcash.isSynced ? Color.neonGreen : Color.orange)
                            .frame(width: 8, height: 8)
                            .shadow(color: zcash.isSynced ? .neonGreen : .orange, radius: 4)
                        
                        Text(zcash.isSynced ? "READY" : "SYNCING...")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
                
                // MARK: - MAIN INTERFACE
                if showReceiveMode {
                    ReceiveRadarView(bleService: bleService)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    // MARK: - SEND MODE (The "Check")
                    VStack(spacing: 30) {
                        
                        // Balance Display
                        VStack(spacing: 5) {
                            Text("AVAILABLE BALANCE")
                                .font(.caption)
                                .tracking(2)
                                .foregroundColor(.gray)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("ZEC")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.zcashGold)
                                Text("\(zcash.balance, specifier: "%.4f")")
                                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // The Physical "Check" Card
                        ZStack {
                            // Card Glow
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black)
                                .shadow(color: Color.zcashGold.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            // Card Border
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(gradient: Gradient(colors: [.zcashGold, .zcashGold.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 2
                                )
                            
                            VStack(spacing: 20) {
                                HStack {
                                    Image(systemName: "signature")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "qrcode")
                                        .foregroundColor(.gray)
                                }
                                
                                // Amount Input
                                VStack(spacing: 10) {
                                    Text("PAY TO THE ORDER OF")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.zcashGold)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    HStack(spacing: 0) {
                                        Text("ZEC")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white.opacity(0.6))
                                            .padding(.trailing, 10)
                                        
                                        TextField("0.00", text: $amount)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 44, weight: .medium, design: .monospaced))
                                            .foregroundColor(.white)
                                            .accentColor(.zcashGold)
                                    }
                                    
                                    Divider().background(Color.white.opacity(0.2))
                                }
                                
                                HStack {
                                    Text("MEMO: OFFLINE TRANSFER")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .padding(25)
                        }
                        .frame(height: 220)
                        .padding(.horizontal)
                        .offset(y: dragOffset.height) // Physics Animation
                        .rotation3DEffect(.degrees(Double(dragOffset.height / 10)), axis: (x: 1, y: 0, z: 0))
                        .opacity(isSending ? 0 : 1)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Only allow dragging UP
                                    if value.translation.height < 0 {
                                        self.dragOffset = value.translation
                                        prepareHaptics()
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height < -150 {
                                        // SWIPED UP -> SEND!
                                        playSoundAndSend()
                                    } else {
                                        // Snap back
                                        withAnimation(.spring()) {
                                            self.dragOffset = .zero
                                        }
                                    }
                                }
                        )
                        
                        // Swipe Instruction
                        if !isSending {
                            VStack(spacing: 8) {
                                Image(systemName: "chevron.up")
                                    .foregroundColor(.white.opacity(0.5))
                                    .offset(y: -5)
                                    .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
                                Text("SWIPE CARD UP TO SEND")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(1)
                            }
                            .opacity(amount.isEmpty ? 0 : 1)
                        }
                    }
                    .transition(.move(edge: .bottom))
                }
                
                Spacer()
                
                // MARK: - BOTTOM TOGGLE BAR
                HStack {
                    Button(action: { withAnimation { showReceiveMode = false } }) {
                        VStack {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20))
                            Text("Send")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(!showReceiveMode ? .zcashGold : .gray)
                    }
                    
                    Button(action: { withAnimation { showReceiveMode = true } }) {
                        VStack {
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 20))
                            Text("Receive")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(showReceiveMode ? .neonGreen : .gray)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                .background(Color.black.opacity(0.3))
                .cornerRadius(30, corners: [.topLeft, .topRight])
            }
        }
        .onAppear(perform: prepareHapticsEngine)
        // INITIALIZE THE WALLET ON LOAD
        .onAppear {
            // NOTE: In production, fetch this from Keychain!
            // For now, this is where the seed enters the app securely (not hardcoded deep in the engine)
            zcash.startEngine(seedPhrase: "YOUR_REAL_SEED_PHRASE_HERE_OR_FROM_KEYCHAIN")
        }
    }
    
    // MARK: - ACTIONS
    
    func playSoundAndSend() {
        guard let value = Double(amount) else { return }
        
        // 1. Visual Animation: Card flies away
        withAnimation(.easeOut(duration: 0.4)) {
            self.dragOffset = CGSize(width: 0, height: -600)
            self.isSending = true
        }
        
        // 2. Haptic "Thud"
        playHapticSuccess()
        
        // 3. Trigger Logic
        Task {
            do {
                // Mock Delay for "Signing" visuals
                try await Task.sleep(nanoseconds: 500_000_000)
                
                let rawTx = try await zcash.createProposal(amount: value, toAddress: "dummy")
                
                // Hardware Sign (Simulated wrapper)
                let signature = try await HardwareSigner.shared.signPayload(data: rawTx)
                let packet = signature + "|||".data(using: String.Encoding.utf8)! + rawTx
                
                // Blast via Bluetooth
                bleService.startSending(data: packet)
                
                // Reset UI after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.amount = ""
                        self.dragOffset = .zero
                        self.isSending = false
                    }
                }
            } catch {
                print("Send Failed: \(error)")
                withAnimation { self.dragOffset = .zero } // Reset on fail
            }
        }
    }
    
    // MARK: - HAPTICS ENGINE
    func prepareHapticsEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptics Error: \(error)")
        }
    }
    
    func prepareHaptics() {
        // Light vibration while dragging
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func playHapticSuccess() {
        // Heavy "Cash" Thud
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - SUBVIEW: RECEIVE RADAR
struct ReceiveRadarView: View {
    @ObservedObject var bleService: BLEService
    @State private var waveScale: CGFloat = 0.5
    @State private var waveOpacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 40) {
            
            Text(bleService.status == "Idle" ? "WAITING FOR ZEC..." : bleService.status.uppercased())
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.neonGreen)
                .tracking(2)
            
            ZStack {
                // Radar Waves
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.neonGreen.opacity(0.3), lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .scaleEffect(waveScale)
                        .opacity(waveOpacity)
                        .animation(
                            Animation.easeOut(duration: 2)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.6),
                            value: waveScale
                        )
                }
                
                // Center Icon
                Circle()
                    .fill(Color.neonGreen.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "wifi")
                            .font(.system(size: 40))
                            .foregroundColor(.neonGreen)
                    )
                    .shadow(color: .neonGreen, radius: 20)
            }
            .onAppear {
                self.waveScale = 2.0
                self.waveOpacity = 0.0
                bleService.startReceiving()
            }
            
            if bleService.progress > 0 {
                // Progress Bar
                VStack {
                    Text("\(Int(bleService.progress * 100))%")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    
                    ProgressView(value: bleService.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .neonGreen))
                        .padding(.horizontal, 50)
                }
            }
        }
    }
}

// MARK: - UTILS: CORNER RADIUS HELPER
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
