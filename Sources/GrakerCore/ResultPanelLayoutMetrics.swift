import CoreGraphics
import Foundation

public enum ResultPanelLayoutMetrics {
    public static let panelWidth: CGFloat = 540
    public static let rootHorizontalInsets: CGFloat = 36
    public static let goodToKnowHorizontalInsets: CGFloat = 24

    public static var contentTextWidth: CGFloat {
        panelWidth - rootHorizontalInsets
    }

    public static var goodToKnowTextWidth: CGFloat {
        contentTextWidth - goodToKnowHorizontalInsets
    }
}
