//
//  ChartStackSection.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

private enum Constants {
    static let chartViewHeightFraction: CGFloat = 0.55
}

class ChartStackSection: UIView, ColorModeContainer {
    @IBOutlet var chartView: ChartView!
    @IBOutlet var rangeView: RangeChartView!
    @IBOutlet var visibilityView: ChartVisibilityView!
    @IBOutlet var sectionContainerView: UIView!
    @IBOutlet var separators: [UIView]!
    
    @IBOutlet var headerLabel: UILabel!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var backButton: UIButton!
    @IBOutlet var backButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet var chartHeightConstraint: NSLayoutConstraint!
    
    var controller: BaseChartController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        headerLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        visibilityView.clipsToBounds = true
        backButton.isExclusiveTouch = true
        
        let screenSize = UIScreen.main.bounds.size
        let cellHeight = max(screenSize.width, screenSize.height) * Constants.chartViewHeightFraction
        chartHeightConstraint.constant = cellHeight.rounded(.up)
        
        backButtonWidthConstraint.constant = 0
        backButton.setVisible(false, animated: false)
    }
    
    func apply(colorMode: ColorMode, animated: Bool) {
        UIView.perform(animated: animated && self.isVisibleInWindow) {
            self.backgroundColor = colorMode.tableBackgroundColor
            
            self.sectionContainerView.backgroundColor = colorMode.chartBackgroundColor
            self.rangeView.backgroundColor = colorMode.chartBackgroundColor
            self.visibilityView.backgroundColor = colorMode.chartBackgroundColor
            
            self.backButton.tintColor = colorMode.actionButtonColor
            self.backButton.setTitleColor(colorMode.actionButtonColor, for: .normal)
            
            for separator in self.separators {
                separator.backgroundColor = colorMode.tableSeparatorColor
            }
        }
        
        if rangeView.isVisibleInWindow || chartView.isVisibleInWindow {
            chartView.loadDetailsViewIfNeeded()
            chartView.apply(colorMode: colorMode, animated: animated && chartView.isVisibleInWindow)
            controller.apply(colorMode: colorMode, animated: animated)
            rangeView.apply(colorMode: colorMode, animated: animated && rangeView.isVisibleInWindow)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval.random(in: 0...0.1)) {
                self.chartView.loadDetailsViewIfNeeded()
                self.controller.apply(colorMode: colorMode, animated: false)
                self.chartView.apply(colorMode: colorMode, animated: false)
                self.rangeView.apply(colorMode: colorMode, animated: false)
            }
        }
        
        self.titleLabel.setTextColor(colorMode.chartTitleColor, animated: animated && titleLabel.isVisibleInWindow)
        self.headerLabel.setTextColor(colorMode.sectionTitleColor, animated: animated && headerLabel.isVisibleInWindow)
    }
    
    @IBAction func didTapBackButton() {
        controller.didTapZoomOut()
    }
    
    func setBackButtonVisible(_ visible: Bool, animated: Bool) {
        backButton.setVisible(visible, animated: animated)
        backButtonWidthConstraint.isActive = !visible
        layoutIfNeeded(animated: animated)
    }
    
    func updateToolViews(animated: Bool) {
        rangeView.setRange(controller.currentChartHorizontalRangeFraction, animated: animated)
        rangeView.setRangePaging(enabled: controller.isChartRangePagingEnabled,
                                 minimumSize: controller.minimumSelectedChartRange)
        visibilityView.setVisible(controller.drawChartVisibity, animated: animated)
        if controller.drawChartVisibity {
            visibilityView.isExpanded = true
            visibilityView.items = controller.actualChartsCollection.chartValues.map { value in
                return ChartVisibilityItem(title: value.name, color: value.color)
            }
            visibilityView.setItemsSelection(controller.actualChartVisibility)
            visibilityView.setNeedsLayout()
            visibilityView.layoutIfNeeded()
        } else {
            visibilityView.isExpanded = false
        }
        superview?.superview?.layoutIfNeeded(animated: animated)
    }
    
    func setup(controller: BaseChartController, title: String) {
        self.controller = controller
        self.headerLabel.text = title
        
        // Chart
        chartView.renderers = controller.mainChartRenderers
        chartView.userDidSelectCoordinateClosure = { [unowned self] point in
            self.controller.chartInteractionDidBegin(point: point)
        }
        chartView.userDidDeselectCoordinateClosure = { [unowned self] in
            self.controller.chartInteractionDidEnd()
        }
        controller.cartViewBounds = { [unowned self] in
            return self.chartView.bounds
        }
        controller.chartFrame = { [unowned self] in
            return self.chartView.chartFrame
        }
        controller.setDetailsViewModel = { [unowned self] viewModel, animated in
            self.chartView.setDetailsViewModel(viewModel: viewModel, animated: animated)
        }
        controller.setDetailsChartVisibleClosure = { [unowned self] visible, animated in
            self.chartView.setDetailsChartVisible(visible, animated: animated)
        }
        controller.setDetailsViewPositionClosure = { [unowned self] position in
            self.chartView.detailsViewPosition = position
        }
        controller.setChartTitleClosure = { [unowned self] title, animated in
            self.titleLabel.setText(title, animated: animated)
        }
        controller.setBackButtonVisibilityClosure = { [unowned self] visible, animated in
            self.setBackButtonVisible(visible, animated: animated)
        }
        controller.refreshChartToolsClosure = { [unowned self] animated in
            self.updateToolViews(animated: animated)
        }
        
        // Range view
        rangeView.chartView.renderers = controller.navigationRenderers
        rangeView.rangeDidChangeClosure = { range in
            controller.updateChartRange(range)
        }
        rangeView.touchedOutsideClosure = {
            controller.cancelChartInteraction()
        }
        controller.chartRangeUpdatedClosure = { [unowned self] (range, animated) in
            self.rangeView.setRange(range, animated: animated)
        }
        controller.chartRangePagingClosure = {  [unowned self] (isEnabled, pageSize) in
            self.rangeView.setRangePaging(enabled: isEnabled, minimumSize: pageSize)
        }
        
        // Visibility view
        visibilityView.selectionCallbackClosure = { [unowned self] visibility in
            self.controller.updateChartsVisibility(visibility: visibility, animated: true)
        }
        
        controller.initializeChart()
        updateToolViews(animated: false)
    }
}
