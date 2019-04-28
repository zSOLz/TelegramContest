//
//  ChartView.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

public protocol ChartViewRenderer: class {
    var containerViews: [UIView] { get set }
    func render(context: CGContext, bounds: CGRect, chartFrame: CGRect)
}

class ChartView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setupView()
    }
    
    var chartInsets: UIEdgeInsets = UIEdgeInsets(top: 40, left: 16, bottom: 35, right: 16) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var renderers: [ChartViewRenderer] = [] {
        willSet {
            renderers.forEach { $0.containerViews.removeAll(where: { $0 == self }) }
        }
        didSet {
            renderers.forEach { $0.containerViews.append(self) }
            setNeedsDisplay()
        }
    }
    
    var chartFrame: CGRect {
        let chartBound = self.bounds
        return CGRect(x: chartInsets.left,
                      y: chartInsets.top,
                      width: max(1, chartBound.width - chartInsets.left - chartInsets.right),
                      height: max(1, chartBound.height - chartInsets.top - chartInsets.bottom))
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let chartBounds = self.bounds
        let chartFrame = self.chartFrame
        
        for renderer in renderers {
            renderer.render(context: context, bounds: chartBounds, chartFrame: chartFrame)
        }
    }
    
    var userDidSelectCoordinateClosure: ((CGPoint) -> Void)?
    var userDidDeselectCoordinateClosure: (() -> Void)?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let point = touches.first?.location(in: self) {
            let fractionPoint = CGPoint(x: (point.x - chartFrame.origin.x) / chartFrame.width,
                                        y: (point.y - chartFrame.origin.y) / chartFrame.height)
            userDidSelectCoordinateClosure?(fractionPoint)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let point = touches.first?.location(in: self) {
            let fractionPoint = CGPoint(x: (point.x - chartFrame.origin.x) / chartFrame.width,
                                        y: (point.y - chartFrame.origin.y) / chartFrame.height)
            userDidSelectCoordinateClosure?(fractionPoint)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        userDidDeselectCoordinateClosure?()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        userDidDeselectCoordinateClosure?()
    }
    
    // MARK: Details View
    
    private var detailsView: ChartDetailsView!
    private var maxDetailsViewWidth: CGFloat = 0
    func loadDetailsViewIfNeeded() {
        if detailsView == nil {
            let detailsView = ChartDetailsView(frame: bounds)
            addSubview(detailsView)
            detailsView.alpha = 0
            self.detailsView = detailsView
        }
    }
    
    private var detailsTableTopOffset: CGFloat = 5
    private var detailsTableLeftOffset: CGFloat = 8
    private var isDetailsViewVisible: Bool = false

    var detailsViewPosition: CGFloat = 0 {
        didSet {
            loadDetailsViewIfNeeded()
            let detailsViewSize = detailsView.intrinsicContentSize
            maxDetailsViewWidth = max(maxDetailsViewWidth, detailsViewSize.width)
            if maxDetailsViewWidth + detailsTableLeftOffset > detailsViewPosition {
                detailsView.frame = CGRect(x: min(detailsViewPosition + detailsTableLeftOffset, bounds.width - maxDetailsViewWidth),
                                           y: chartInsets.top + detailsTableTopOffset,
                                           width: maxDetailsViewWidth,
                                           height: detailsViewSize.height)
            } else {
                detailsView.frame = CGRect(x: detailsViewPosition - maxDetailsViewWidth - detailsTableLeftOffset,
                                           y: chartInsets.top + detailsTableTopOffset,
                                           width: maxDetailsViewWidth,
                                           height: detailsViewSize.height)
            }
        }
    }
    
    func setDetailsChartVisible(_ visible: Bool, animated: Bool) {
        guard isDetailsViewVisible != visible else {
            return
        }
        isDetailsViewVisible = visible
        loadDetailsViewIfNeeded()
        detailsView.setVisible(visible, animated: animated)
        if !visible {
            maxDetailsViewWidth = 0
        }
    }
    
    func setDetailsViewModel(viewModel: ChartDetailsViewModel, animated: Bool) {
        loadDetailsViewIfNeeded()
        detailsView.setup(viewModel: viewModel, animated: animated)
        UIView.perform(animated: animated, animations: {
            let position = self.detailsViewPosition
            self.detailsViewPosition = position
        })
    }

    func setupView() {
        backgroundColor = .clear
        layer.drawsAsynchronously = true
    }
}


extension ChartView: ColorModeContainer {
    func apply(colorMode: ColorMode, animated: Bool) {
        detailsView?.apply(colorMode: colorMode, animated: animated && (detailsView?.isVisibleInWindow ?? false))
    }
}
