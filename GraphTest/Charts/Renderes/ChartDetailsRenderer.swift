//
//  ChartDetailsRenderer.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

class ChartDetailsRenderer: BaseChartRenderer, ColorModeContainer {
    private lazy var colorAnimator = AnimationController<CGFloat>(current: 1, refreshClosure: refreshClosure)
    private var fromColorMode: ColorMode = .day
    private var currentColorMode: ColorMode = .day
    func apply(colorMode: ColorMode, animated: Bool) {
        if currentColorMode != colorMode {
            fromColorMode = currentColorMode
            currentColorMode = colorMode
            if animated {
                colorAnimator.set(current: 0)
                colorAnimator.animate(to: 1, duration: .defaultDuration)
            } else {
                colorAnimator.set(current: 1)
            }
        }
    }
    
    private var valuesAnimators: [AnimationController<CGFloat>] = []
    func setValueVisible(_ isVisible: Bool, at index: Int, animated: Bool) {
        valuesAnimators[index].animate(to: isVisible ? 1 : 0, duration: animated ? .defaultDuration : 0)
    }
    var detailsViewModel: ChartDetailsViewModel = .blank {
        didSet {
            if detailsViewModel.values.count != valuesAnimators.count {
                valuesAnimators = detailsViewModel.values.map { _ in AnimationController<CGFloat>(current: 1, refreshClosure: refreshClosure) }
            }
            setNeedsDisplay()
        }
    }
    
    var detailsViewPosition: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    var detailViewPositionOffset: CGFloat = 10
    var detailViewTopOffset: CGFloat = 10
    private var iconWidth: CGFloat = 10
    private var margins: CGFloat = 10
    private let cornerRadius: CGFloat = 5
    private var rowHeight: CGFloat = 20
    private let titleFont = UIFont.systemFont(ofSize: 14, weight: .bold)
    private let prefixFont = UIFont.systemFont(ofSize: 14, weight: .bold)
    private let labelsFont = UIFont.systemFont(ofSize: 14, weight: .medium)
    private let valuesFont = UIFont.systemFont(ofSize: 14, weight: .bold)
    private let labelsColor: UIColor = .black
    
    private(set) var previousRenderBannerFrame: CGRect = .zero
    override func render(context: CGContext, bounds: CGRect, chartFrame: CGRect) {
        previousRenderBannerFrame = .zero
        guard isEnabled && verticalRange.current.distance > 0 && verticalRange.current.distance > 0 else { return }
        let generalAlpha = chartAlphaAnimator.current
        if generalAlpha == 0 { return }
        
        let widths: [(prefix: CGFloat, label: CGFloat, value: CGFloat)] = detailsViewModel.values.map { value in
            var prefixWidth: CGFloat = 0
            if let prefixText = value.prefix {
                prefixWidth = (prefixText as NSString).boundingRect(with: bounds.size,
                                                                    options: .usesLineFragmentOrigin,
                                                                    attributes: [.font: prefixFont],
                                                                    context: nil).width.rounded(.up) + margins
            }
            
            let labelWidth = (value.title as NSString).boundingRect(with: bounds.size,
                                                                    options: .usesLineFragmentOrigin,
                                                                    attributes: [.font: labelsFont],
                                                                    context: nil).width.rounded(.up) + margins
            
            let valueWidth = (value.value as NSString).boundingRect(with: bounds.size,
                                                                    options: .usesLineFragmentOrigin,
                                                                    attributes: [.font: valuesFont],
                                                                    context: nil).width.rounded(.up)
            return (prefixWidth, labelWidth, valueWidth)
        }
        
        let titleWidth = (detailsViewModel.title as NSString).boundingRect(with: bounds.size,
                                                                           options: .usesLineFragmentOrigin,
                                                                           attributes: [.font: titleFont],
                                                                           context: nil).width
        let prefixesWidth = widths.map { $0.prefix }.max() ?? 0
        let labelsWidth = widths.map { $0.label }.max() ?? 0
        let valuesWidth = widths.map { $0.value }.max() ?? 0
        
        let totalWidth: CGFloat = max(prefixesWidth + labelsWidth + valuesWidth, titleWidth + iconWidth) + margins * 2
        let totalHeight: CGFloat = CGFloat(detailsViewModel.values.count + 1) * rowHeight + margins * 2
        let backgroundColor = UIColor.valueBetween(start: fromColorMode.chartDetailsViewColor,
                                                   end: currentColorMode.chartDetailsViewColor,
                                                   offset: Double(colorAnimator.current))
        let titleAndTextColor = UIColor.valueBetween(start: fromColorMode.chartDetailsTextColor,
                                                     end: currentColorMode.chartDetailsTextColor,
                                                     offset: Double(colorAnimator.current))
        let detailsViewFrame: CGRect
        if totalWidth + detailViewTopOffset > detailsViewPosition {
            detailsViewFrame = CGRect(x: detailsViewPosition + detailViewTopOffset,
                                      y: detailViewTopOffset + chartFrame.minY,
                                      width: totalWidth,
                                      height: totalHeight)
        } else {
            detailsViewFrame = CGRect(x: detailsViewPosition - totalWidth - detailViewTopOffset,
                                      y: detailViewTopOffset + chartFrame.minY,
                                      width: totalWidth,
                                      height: totalHeight)
        }
        previousRenderBannerFrame = detailsViewFrame
        context.saveGState()
        context.setFillColor(backgroundColor.cgColor)
        context.beginPath()
        context.addPath(CGPath(roundedRect: detailsViewFrame, cornerWidth: 5, cornerHeight: 5, transform: nil))
        context.fillPath()
        context.endPage()
        context.restoreGState()

        var drawY = detailsViewFrame.minY + margins + (rowHeight - titleFont.pointSize) / 2
        (detailsViewModel.title as NSString).draw(at: CGPoint(x: detailsViewFrame.minX + margins, y: drawY), withAttributes:  [.font: titleFont,
                                                                                                                               .foregroundColor: titleAndTextColor])
        drawY += rowHeight
        
        for (index, row) in widths.enumerated() {
            let value = detailsViewModel.values[index]
            if let prefixText = value.prefix {
                (prefixText as NSString).draw(at: CGPoint(x: detailsViewFrame.minX + prefixesWidth - row.prefix,
                                                          y: drawY),
                                              withAttributes:  [.font: prefixText, .foregroundColor: titleAndTextColor])
            }
            
            (value.title as NSString).draw(at: CGPoint(x: detailsViewFrame.minX + prefixesWidth + margins,
                                                       y: drawY),
                                           withAttributes:  [.font: labelsFont, .foregroundColor: titleAndTextColor])
            
            (value.value as NSString).draw(at: CGPoint(x: detailsViewFrame.minX + prefixesWidth + labelsWidth + valuesWidth - row.value  + margins,
                                                       y: drawY),
                                           withAttributes:  [.font: labelsFont, .foregroundColor: value.color])
            
            drawY += rowHeight
        }
    }
}
