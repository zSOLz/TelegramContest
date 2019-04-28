//
//  GeneralChartComponentController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

enum GeneralChartComponentConstants {
    static let defaultInitialRangeLength = CGFloat(TimeInterval.day * 60)
    static let defaultZoomedRangeLength = CGFloat(TimeInterval.day)
}

class GeneralChartComponentController: ColorModeContainer {
    var chartsCollection: ChartsCollection = ChartsCollection.blank
    var chartVisibility: [Bool] = []
    var lastChartInteractionPoint: CGPoint = .zero
    var isChartInteractionBegun: Bool = false
    var isChartInteracting: Bool = false
    let isZoomed: Bool
    
    var colorMode: ColorMode = .day
    var totalHorizontalRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    var totalVerticalRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    var initialHorizontalRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    var initialVerticalRange: ClosedRange<CGFloat> = BaseConstants.defaultRange
    
    var cartViewBounds: (() -> CGRect) = { fatalError() }
    var chartFrame: (() -> CGRect) = { fatalError() }
    
    init(isZoomed: Bool) {
        self.isZoomed = isZoomed
    }
    
    func initialize(chartsCollection: ChartsCollection,
                    initialDate: Date,
                    totalHorizontalRange: ClosedRange<CGFloat>,
                    totalVerticalRange: ClosedRange<CGFloat>) {
        self.chartsCollection = chartsCollection
        self.chartVisibility = Array(repeating: true, count: chartsCollection.chartValues.count)
        self.totalHorizontalRange = totalHorizontalRange
        self.totalVerticalRange = totalVerticalRange
        self.initialHorizontalRange = totalHorizontalRange
        self.initialVerticalRange = totalVerticalRange

        didLoad()
        setupInitialChartRange(initialDate: initialDate)
    }
    
    func didLoad() {
        hideDetailsView(animated: false)
    }
    func willAppear(animated: Bool) {
        updateChartRangeTitle(animated: animated)
        setupChartRangePaging()
    }
    func willDisappear(animated: Bool) {
    }
    
    func setupInitialChartRange(initialDate: Date) {
        guard let first = chartsCollection.axisValues.first?.timeIntervalSince1970,
            let last = chartsCollection.axisValues.last?.timeIntervalSince1970 else { return }
        
        let rangeStart = CGFloat(first)
        let rangeEnd = CGFloat(last)

        if isZoomed {
            let initalDate = CGFloat(initialDate.timeIntervalSince1970)

            initialHorizontalRange = max(initalDate, rangeStart)...min(initalDate + GeneralChartComponentConstants.defaultZoomedRangeLength, rangeEnd)
            initialVerticalRange = totalVerticalRange
        } else {
            initialHorizontalRange = max(rangeStart, rangeEnd - GeneralChartComponentConstants.defaultInitialRangeLength)...rangeEnd
            initialVerticalRange = totalVerticalRange
        }
    }
    func setupChartRangePaging() {
        chartRangePagingClosure?(false, 0.05)
    }

    var visibleHorizontalMainChartRange: ClosedRange<CGFloat> {
        return currentMainRangeRenderer.verticalRange.current
    }
    var visibleVerticalMainChartRange: ClosedRange<CGFloat> {
        return currentMainRangeRenderer.verticalRange.current
    }
    var currentHorizontalMainChartRange: ClosedRange<CGFloat> {
        return currentMainRangeRenderer.horizontalRange.end
    }
    var currentVerticalMainChartRange: ClosedRange<CGFloat> {
        return currentMainRangeRenderer.verticalRange.end
    }
    var currentMainRangeRenderer: BaseChartRenderer {
        fatalError("Abstract")
    }
    
    var visiblePreviewHorizontalRange: ClosedRange<CGFloat> {
        return currentPreviewRangeRenderer.verticalRange.current
    }
    var visiblePreviewVerticalRange: ClosedRange<CGFloat> {
        return currentPreviewRangeRenderer.verticalRange.current
    }
    var currentPreviewHorizontalRange: ClosedRange<CGFloat> {
        return currentPreviewRangeRenderer.horizontalRange.end
    }
    var currentPreviewVerticalRange: ClosedRange<CGFloat> {
        return currentPreviewRangeRenderer.verticalRange.end
    }
    var currentPreviewRangeRenderer: BaseChartRenderer {
        fatalError("Abstract")
    }
    
    var mainChartRenderers: [ChartViewRenderer] {
        fatalError("Abstract")
    }
    var previewRenderers: [ChartViewRenderer] {
        fatalError("Abstract")
    }
    
    func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        self.chartVisibility = visibility
        if isChartInteractionBegun {
            chartInteractionDidBegin(point: lastChartInteractionPoint)
        }
    }
    
    var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        let lowerPercent = (currentHorizontalMainChartRange.lowerBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        let upperPercent = (currentHorizontalMainChartRange.upperBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        return lowerPercent...upperPercent
    }
    
    func chartRangeFractionDidUpdated(_ rangeFraction: ClosedRange<CGFloat>) {
        let horizontalRange = ClosedRange(uncheckedBounds:
            (lower: totalHorizontalRange.lowerBound + rangeFraction.lowerBound * totalHorizontalRange.distance,
             upper: totalHorizontalRange.lowerBound + rangeFraction.upperBound * totalHorizontalRange.distance))
        chartRangeDidUpdated(horizontalRange)
        updateChartRangeTitle(animated: true)
    }
    
    func chartRangeDidUpdated(_ updatedRange: ClosedRange<CGFloat>) {
        hideDetailsView(animated: true)
        
        if isChartInteractionBegun {
            chartInteractionDidBegin(point: lastChartInteractionPoint)
        }
    }
    
    // MARK: - Details & Interaction
    func findClosestDateTo(dateToFind: Date) -> (Date, Int)? {
        guard chartsCollection.axisValues.count > 0 else { return nil }
        var closestDate = chartsCollection.axisValues[0]
        var minIndex = 0
        for (index, date) in chartsCollection.axisValues.enumerated() {
            if abs(dateToFind.timeIntervalSince(date)) < abs(dateToFind.timeIntervalSince(closestDate)) {
                closestDate = date
                minIndex = index
            }
        }
        return (closestDate, minIndex)
    }
    
    func chartInteractionDidBegin(point: CGPoint) {
        let chartFrame = self.chartFrame()
        guard chartFrame.width > 0 else { return }
        let horizontalRange = currentHorizontalMainChartRange
        let dateToFind = Date(timeIntervalSince1970: TimeInterval(horizontalRange.distance * point.x + horizontalRange.lowerBound))
        guard let (closestDate, minIndex) = findClosestDateTo(dateToFind: dateToFind) else { return }
        
        let chartWasInteracting = isChartInteractionBegun
        lastChartInteractionPoint = point
        isChartInteractionBegun = true
        isChartInteracting = true
        
        let chartValue: CGFloat = CGFloat(closestDate.timeIntervalSince1970)
        let detailsViewPosition = (chartValue - horizontalRange.lowerBound) / horizontalRange.distance * chartFrame.width + chartFrame.minX
        showDetailsView(at: chartValue, detailsViewPosition: detailsViewPosition, dataIndex: minIndex, date: closestDate, animted: chartWasInteracting)
    }
    
    func showDetailsView(at chartPosition: CGFloat, detailsViewPosition: CGFloat, dataIndex: Int, date: Date, animted: Bool) {
        setDetailsViewModel?(chartDetailsViewModel(closestDate: date, pointIndex: dataIndex), animted)
        setDetailsChartVisibleClosure?(true, true)
        setDetailsViewPositionClosure?(detailsViewPosition)
    }
    
    func chartInteractionDidEnd() {
        isChartInteracting = false
    }

    func hideDetailsView(animated: Bool) {
        isChartInteractionBegun = false
        setDetailsChartVisibleClosure?(false, animated)
    }
    
    var visibleDetailsChartValues: [ChartsCollection.Chart] {
        let visibleCharts: [ChartsCollection.Chart] = chartVisibility.enumerated().compactMap { args in
            args.element ? chartsCollection.chartValues[args.offset] : nil
        }
        return visibleCharts
    }
    
    var updatePreviewRangeClosure: ((ClosedRange<CGFloat>, Bool) -> Void)?
    var zoomInOnDateClosure: ((Date) -> Void)?
    var setChartTitleClosure: ((String, Bool) -> Void)?
    var setDetailsViewPositionClosure: ((CGFloat) -> Void)?
    var setDetailsChartVisibleClosure: ((Bool, Bool) -> Void)?
    var setDetailsViewModel: ((ChartDetailsViewModel, Bool) -> Void)?
    var chartRangePagingClosure: ((Bool, CGFloat) -> Void)? // isEnabled, PageSize
    
    func apply(colorMode: ColorMode, animated: Bool) {
        self.colorMode = colorMode
    }

// MARK: - Helpers
    var prevoiusHorizontalStrideInterval: Int = -1
    func updateHorizontalLimitLabels(horizontalScalesRenderer: HorizontalScalesRenderer,
                                     horizontalRange: ClosedRange<CGFloat>,
                                     scaleType: ChartScaleType,
                                     forceUpdate: Bool,
                                     animated: Bool) {
        let scaleTimeInterval: TimeInterval
        if chartsCollection.axisValues.count >= 1 {
            scaleTimeInterval = chartsCollection.axisValues[1].timeIntervalSince1970 - chartsCollection.axisValues[0].timeIntervalSince1970
        } else {
            scaleTimeInterval = scaleType.timeInterval
        }
            
        let numberOfItems = horizontalRange.distance / CGFloat(scaleTimeInterval)
        let maximumNumberOfItems = chartFrame().width / scaleType.minimumAxisXDistance
        let tempStride = max(1, Int((numberOfItems / maximumNumberOfItems).rounded(.up)))
        var strideInterval = 1
        while strideInterval < tempStride {
            strideInterval *= 2
        }
        
        if forceUpdate || (strideInterval != prevoiusHorizontalStrideInterval && strideInterval > 0) {
            var labels: [LinesChartLabel] = []
            for index in stride(from: chartsCollection.axisValues.count - 1, to: -1, by: -strideInterval).reversed() {
                let date = chartsCollection.axisValues[index]
                labels.append(LinesChartLabel(value: CGFloat(date.timeIntervalSince1970),
                                              text: scaleType.dateFormatter.string(from: date)))
            }
            prevoiusHorizontalStrideInterval = strideInterval
            horizontalScalesRenderer.setup(labels: labels, animated: animated)
        }
    }
    
    func verticalLimitsLabels(verticalRange: ClosedRange<CGFloat>) -> (ClosedRange<CGFloat>, [LinesChartLabel]) {
        let ditance = verticalRange.distance
        let chartHeight = chartFrame().height
        
        guard ditance > 0, chartHeight > 0 else { return (BaseConstants.defaultRange, [LinesChartLabel(value: 0, text: "0")]) }
        
        let approximateNumberOfChartValues = (chartHeight / BaseConstants.minimumAxisYLabelsDistance)
        
        var numberOfOffsetsPerItem = ditance / approximateNumberOfChartValues
        var multiplier: CGFloat = 1.0
        while numberOfOffsetsPerItem > 10 {
            numberOfOffsetsPerItem /= 10
            multiplier *= 10
        }
        var dividor: CGFloat = 1.0
        var maximumNumberOfDecimals = 2
        while numberOfOffsetsPerItem < 1 {
            numberOfOffsetsPerItem *= 10
            dividor *= 10
            maximumNumberOfDecimals += 1
        }
        
        var base: CGFloat = BaseConstants.verticalBaseAnchors.first { numberOfOffsetsPerItem > $0 } ?? BaseConstants.defaultVerticalBaseAnchor
        base = base * multiplier / dividor
        
        var verticalLabels: [LinesChartLabel] = []
        var verticalValue = (verticalRange.lowerBound / base).rounded(.down) * base
        let lowerBound = verticalValue
        
        let numberFormatter = BaseConstants.chartNumberFormatter
        numberFormatter.maximumFractionDigits = maximumNumberOfDecimals
        while verticalValue < verticalRange.upperBound {
            let text: String = numberFormatter.string(from: NSNumber(value: Double(verticalValue))) ?? ""
            
            verticalLabels.append(LinesChartLabel(value: verticalValue, text: text))
            verticalValue += base
        }
        let updatedRange = lowerBound...verticalValue
        
        return (updatedRange, verticalLabels)
    }

    func chartDetailsViewModel(closestDate: Date, pointIndex: Int) -> ChartDetailsViewModel {
        let values: [ChartDetailsViewModel.Value] = chartsCollection.chartValues.enumerated().map { arg in
            let (index, component) = arg
            return ChartDetailsViewModel.Value(prefix: nil,
                                               title: component.name,
                                               value: BaseConstants.detailsNumberFormatter.string(from: NSNumber(value: component.values[pointIndex])) ?? "",
                                               color: component.color,
                                               visible: chartVisibility[index])
        }
        let dateString: String
        if isZoomed {
            dateString = BaseConstants.timeDateFormatter.string(from: closestDate)
        } else {
            dateString = BaseConstants.headerMediumRangeFormatter.string(from: closestDate)
        }
        let viewModel = ChartDetailsViewModel(title: dateString,
                                              showArrow: !self.isZoomed,
                                              showPrefixes: false,
                                              values: values,
                                              totalValue: nil, 
                                              tapAction: { [weak self] in
                                                self?.zoomInOnDateClosure?(closestDate) })
        return viewModel
    }

    func updateChartRangeTitle(animated: Bool) {
        let fromDate = Date(timeIntervalSince1970: TimeInterval(currentHorizontalMainChartRange.lowerBound) + 1)
        let toDate = Date(timeIntervalSince1970: TimeInterval(currentHorizontalMainChartRange.upperBound))
        if Calendar.utc.startOfDay(for: fromDate) == Calendar.utc.startOfDay(for: toDate) {
            let stirng = BaseConstants.headerFullZoomedFormatter.string(from: fromDate)
            self.setChartTitleClosure?(stirng, animated)
        } else {
            let stirng = "\(BaseConstants.headerMediumRangeFormatter.string(from: fromDate)) - \(BaseConstants.headerMediumRangeFormatter.string(from: toDate))"
            self.setChartTitleClosure?(stirng, animated)
        }
    }
}
