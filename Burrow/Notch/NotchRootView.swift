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

    var body: some View {
        VStack(spacing: 0) {
            notchBody
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(animation, value: viewModel.isExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: activity.current)
    }

    private var notchBody: some View {
        let shape = NotchShape(topRadius: viewModel.topRadius, bottomRadius: viewModel.bottomRadius)
        return ZStack(alignment: .top) {
            shape.fill(Color.black)
            if viewModel.isExpanded {
                ExpandedNotchView(viewModel: viewModel, services: services)
                    .padding(.horizontal, viewModel.topRadius + 14)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)).animation(.easeOut(duration: 0.25).delay(0.06)),
                        removal: .opacity.animation(.easeIn(duration: 0.1))
                    ))
            } else {
                CompactNotchView(activity: activity.current, viewModel: viewModel, services: services)
                    .padding(.horizontal, viewModel.topRadius)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(dropHighlight(shape))
        .shadow(color: .black.opacity(viewModel.isExpanded ? 0.45 : 0), radius: 14, y: 6)
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

    @ViewBuilder
    private func dropHighlight(_ shape: NotchShape) -> some View {
        if viewModel.isDropTargeted {
            shape.stroke(Color.accentColor.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
    }
}
