//
//  PetDetailStackedDemoView.swift
//  Ohana
//
//  3D Stacked Glass Cards Demo — Inspired by frosted glass design
//

import SwiftUI

struct PetDetailStackedDemoView: View {
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDarkMode = true

    let cards = [
        "Overview",
        "Health", 
        "Diet & Care",
        "Records"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0C").ignoresSafeArea()

                // Animated Blobs
                ZStack {
                    Circle().fill(Color.goLime.opacity(0.4)).frame(width: 200).blur(radius: 60).offset(x: -80, y: -150)
                    Circle().fill(Color.goBlue.opacity(0.3)).frame(width: 250).blur(radius: 80).offset(x: 100, y: 50)
                    Circle().fill(Color.goPurple.opacity(0.4)).frame(width: 200).blur(radius: 60).offset(x: -50, y: 200)
                }

                VStack {
                    Spacer()

                    ZStack {
                        ForEach(Array(cards.enumerated().reversed()), id: \.offset) { index, cardTitle in
                            cardView(index: index, title: cardTitle)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.height
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if value.translation.height < -threshold && currentIndex < cards.count - 1 {
                                        currentIndex += 1
                                    } else if value.translation.height > threshold && currentIndex > 0 {
                                        currentIndex -= 1
                                    }
                                    dragOffset = 0
                                }
                            }
                    )

                    Spacer()
                    
                    // Pagination dots
                    HStack(spacing: 8) {
                        ForEach(0..<cards.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentIndex ? Color.goLime : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .scaleEffect(i == currentIndex ? 1.2 : 1.0)
                                .animation(.spring(), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("3D 堆叠演示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1), in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isDarkMode.toggle()
                        }
                    } label: {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isDarkMode ? Color.goYellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1), in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cardView(index: Int, title: String) -> some View {
        let relativeIndex = index - currentIndex
        let isActive = relativeIndex == 0
        
        // Only show cards that are currently active or behind it
        if relativeIndex >= 0 && relativeIndex < 3 {
            let offsetHeight = CGFloat(relativeIndex) * -60 + (isActive ? dragOffset : 0)
            let scale = 1.0 - CGFloat(relativeIndex) * 0.1
            let opacity = 1.0 - Double(relativeIndex) * 0.3
            let yRotation = CGFloat(relativeIndex) * 15
            
            UltimateGlassCard(isDarkMode: isDarkMode) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(title)
                            .font(OhanaFont.title2(.bold))
                            .foregroundStyle(isDarkMode ? .white : .black)
                        Spacer()
                        Image(systemName: "ellipsis")
                            .foregroundStyle(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                    }
                    
                    if index == 0 {
                        // Overview Content
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.goLime.opacity(0.2)).frame(width: 60, height: 60)
                                Text("🐶").font(.system(size: 30))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Buddy").font(OhanaFont.title3(.bold)).foregroundStyle(isDarkMode ? .white : .black)
                                Text("Golden Retriever · 3 Years").font(OhanaFont.caption()).foregroundStyle(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            }
                        }
                        
                        Rectangle().fill(isDarkMode ? .white.opacity(0.1) : .black.opacity(0.05)).frame(height: 1)
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weight").font(OhanaFont.caption()).foregroundStyle(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                Text("24.5 kg").font(OhanaFont.headline(.black)).foregroundStyle(Color.goTeal)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Health").font(OhanaFont.caption()).foregroundStyle(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                Text("Perfect").font(OhanaFont.headline(.black)).foregroundStyle(Color.goLime)
                            }
                        }
                    } else if index == 1 {
                        // Health Content
                        VStack(spacing: 12) {
                            HStack {
                                Text("Vaccines").font(OhanaFont.body(.semibold)).foregroundStyle(isDarkMode ? .white : .black)
                                Spacer()
                                Text("Up to date").font(OhanaFont.caption(.bold)).foregroundStyle(Color.goLime).padding(.horizontal, 8).padding(.vertical, 4).background(Color.goLime.opacity(0.2), in: Capsule())
                            }
                            HStack {
                                Text("Last Vet Visit").font(OhanaFont.body(.semibold)).foregroundStyle(isDarkMode ? .white : .black)
                                Spacer()
                                Text("Oct 12, 2025").font(OhanaFont.caption()).foregroundStyle(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            }
                        }
                    } else if index == 2 {
                        // Diet Content
                        VStack(spacing: 16) {
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Daily Calories").font(OhanaFont.caption()).foregroundStyle(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                    Text("1,240 kcal").font(OhanaFont.title2(.black)).foregroundStyle(isDarkMode ? .white : .black)
                                }
                                Spacer()
                                Image(systemName: "chart.bar.fill").foregroundStyle(Color.goOrange).font(.system(size: 24))
                            }
                            
                            ProgressView(value: 0.7)
                                .tint(Color.goOrange)
                        }
                    } else {
                        // Records Content
                        VStack(spacing: 12) {
                            ForEach(0..<2) { i in
                                HStack {
                                    ZStack {
                                        Circle().fill(Color.goBlue.opacity(0.2)).frame(width: 40, height: 40)
                                        Image(systemName: "figure.walk").foregroundStyle(Color.goBlue)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("Evening Walk").font(OhanaFont.callout(.bold)).foregroundStyle(isDarkMode ? .white : .black)
                                        Text("Today, 6:00 PM").font(OhanaFont.caption()).foregroundStyle(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                    }
                                    Spacer()
                                    Text("45 min").font(OhanaFont.callout(.bold)).foregroundStyle(isDarkMode ? .white : .black)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .frame(height: 320)
            .padding(.horizontal, 30)
            .offset(y: offsetHeight)
            .scaleEffect(scale)
            .opacity(opacity)
            .rotation3DEffect(
                .degrees(Double(yRotation)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.3
            )
            .zIndex(Double(-relativeIndex))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: dragOffset)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
        }
    }
}

#Preview {
    PetDetailStackedDemoView()
}
