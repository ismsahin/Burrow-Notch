import SwiftUI

/// Panelin kök görünümü: üst-orta hizalı çentik gövdesi + içerik.
struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var activity: ActivityCenter
    @ObservedObject var settings: AppSettings
    let services: AppServices

    init(viewModel: NotchViewModel, services: AppServices) {
        self.viewModel = viewModel
        self.services = services
        activity = services.activity
        settings = services.settings
    }

    private var size: CGSize { viewModel.currentSize(for: activity.current) }

    private var animation: Animation {
        viewModel.isExpanded
            ? .spring(response: 0.42, dampingFraction: 0.78)
            : .spring(response: 0.38, dampingFraction: 0.9)
    }

    /// HUD büyürken hafif "aşma" (overshoot) yay: Alcove'daki esneme hissi.
    private var activityAnimation: Animation {
        if case .hud = activity.current { return .spring(response: 0.34, dampingFraction: 0.62) }
        return .spring(response: 0.4, dampingFraction: 0.85)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: viewModel.topInset)
            notchBody
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(animation, value: viewModel.isExpanded)
        .animation(activityAnimation, value: activity.current)
        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.72), value: viewModel.proximity)
    }

    /// Fiziksel çentikte menü çubuğuna kaynaşan çentik şekli; çentiksiz ekranda "ada" seçiliyse yuvarlak hap.
    private var shape: AnyShape {
        if viewModel.isIsland {
            let radius = viewModel.isExpanded ? 30 : min(size.height, viewModel.islandHeight) / 2 + (viewModel.isLargeHUD(activity.current) ? 6 : 0)
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        return AnyShape(NotchShape(topRadius: viewModel.topRadius, bottomRadius: viewModel.bottomRadius))
    }

    private var horizontalInset: CGFloat {
        viewModel.isIsland ? viewModel.islandHeight * 0.25 : viewModel.topRadius
    }

    private var notchBody: some View {
        let shape = shape
        return ZStack(alignment: .top) {
            shape.fill(Color.black)
            if viewModel.isExpanded {
                ExpandedNotchView(viewModel: viewModel, services: services)
                    .padding(.horizontal, horizontalInset + 14)
                    .padding(.top, viewModel.isIsland ? 6 : 0)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)).animation(.easeOut(duration: 0.25).delay(0.06)),
                        removal: .opacity.animation(.easeIn(duration: 0.1))
                    ))
            } else {
                CompactNotchView(activity: activity.current, viewModel: viewModel, services: services)
                    .padding(.horizontal, horizontalInset)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(outline(shape))
        .shadow(color: .black.opacity(shadowOpacity), radius: viewModel.isExpanded ? 14 : 8, y: viewModel.isExpanded ? 6 : 3)
        .contentShape(shape)
        .onTapGesture {
            if !viewModel.isExpanded { viewModel.expand() }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard settings.enableShelf else { return false }
            services.shelf.add(urls)
            viewModel.tab = .shelf
            return true
        } isTargeted: { targeted in
            viewModel.isDropTargeted = targeted
        }
    }

    private var shadowOpacity: Double {
        if viewModel.isExpanded { return 0.45 }
        // Ada her zaman hafif gölgeli (masaüstünden ayrışsın); çentik yalnızca yaklaşınca.
        return (viewModel.isIsland ? 0.25 : 0) + 0.35 * viewModel.proximity
    }

    @ViewBuilder
    private func outline(_ shape: AnyShape) -> some View {
        if viewModel.isDropTargeted {
            shape.stroke(Color.accentColor.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        } else if settings.notchOutline {
            shape.stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }
}
