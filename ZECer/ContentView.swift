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
    // 1. SECURE SEED: Receive from the secure onboarding flow
    @Environment(\.seedPhraseContext) var seedPhrase
    
    // 2. STATE OBJECTS
    @StateObject var zcash = ZcashEngine()
    @StateObject var bleService = BLEService()
    @StateObject var txManager = TxManager.shared
    
    // 3. UI STATE
    @State private var amount: String = ""
    @State private var dragOffset: CGSize = .zero
    @State private var isSending = false
    @State private var showReceiveMode = false
    @State private var showHistory = false // Controls the Activity Sheet
    
    // 4. HAPTICS
    @State private var engine: CHHapticEngine?
    
    var body: some View {
        ZStack {
            // Background
            Color.darkSlate.edgesIgnoringSafeArea(.all)
            
            // Ambient Glow
            Circle()
                .fill(Color.zcashGold.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            VStack(spacing: 0) {
                // MARK: - HEADER
                HStack {
                    // LEFT: Activity / History Button
                    ZStack(alignment: .topTrailing) {
                        Button(action: { showHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        // Red Badge for Pending Txs
                        if !txManager.pendingTxs.isEmpty {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .offset(x: 2, y: -2)
                        }
                    }
                    
                    Spacer()
                    
                    // CENTER: Logo
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.shield.fill")
                            .foregroundColor(.zcashGold)
                        Text("ZECer")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // RIGHT: Sync Status Pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(zcash.isSynced ? Color.neonGreen : Color.orange)
                            .frame(width: 8, height: 8)
                            .shadow(color: zcash.isSynced ? .neonGreen : .orange, radius: 4)
                        
                        Text(zcash.isSynced ? "READY" : "SYNCING")
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
                    // SEND MODE (The "Check")
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
                            // Glow
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black)
                                .shadow(color: Color.zcashGold.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            // Border
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
                        .offset(y: dragOffset.height) // Physics
                        .rotation3DEffect(.degrees(Double(dragOffset.height / 10)), axis: (x: 1, y: 0, z: 0))
                        .opacity(isSending ? 0 : 1)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.height < 0 {
                                        self.dragOffset = value.translation
                                        prepareHaptics()
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height < -150 {
                                        playSoundAndSend()
                                    } else {
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
                        
                        // DEBUG BUTTON (Remove in Production)
                        Button("DEBUG: Simulate Received Cash") {
                            TxManager.shared.saveIncoming(rawHex: "00000FAKE", amount: 0.5, memo: "Test Payment")
                        }
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.top, 10)
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
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                .background(Color.black.opacity(0.3))
                .cornerRadius(30, corners: [.topLeft, .topRight])
            }
        }
        .onAppear(perform: prepareHapticsEngine)
        // INITIALIZE ENGINE WITH SECURE SEED
        .onAppear {
            if !seedPhrase.isEmpty {
                zcash.startEngine(seedPhrase: seedPhrase)
            }
        }
        // PRESENT HISTORY SHEET
        .sheet(isPresented: $showHistory) {
            ActivityView(zcashEngine: zcash)
        }
    }
    
    // MARK: - ACTIONS
    
    func playSoundAndSend() {
        guard let value = Double(amount) else { return }
        
        withAnimation(.easeOut(duration: 0.4)) {
            self.dragOffset = CGSize(width: 0, height: -600)
            self.isSending = true
        }
        
        playHapticSuccess()
        
        Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                
                let rawTx = try await zcash.createProposal(amount: value, toAddress: "dummy")
                
                // 1. NEW: Save to History immediately
                DispatchQueue.main.async {
                    txManager.saveOutgoing(amount: value, memo: "Offline Transfer to Peer")
                }
                
                // Hardware Sign & Broadcast
                let signature = try await HardwareSigner.shared.signPayload(data: rawTx)
                let packet = signature + "|||".data(using: String.Encoding.utf8)! + rawTx
                
                bleService.startSending(data: packet)
                
                // Reset UI
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.amount = ""
                        self.dragOffset = .zero
                        self.isSending = false
                    }
                }
            } catch {
                print("Send Failed: \(error)")
                withAnimation { self.dragOffset = .zero }
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
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func playHapticSuccess() {
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
