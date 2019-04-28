//
//  TwoAxisLinesChartController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

private enum Constants {
    static let verticalBaseAnchors: [CGFloat] = [9, 8, 6, 5, 4, 3, 2.5, 2, 1.5, 1, 0.5]
    static let defaultRange: ClosedRange<CGFloat> = 0...1
}

class TwoAxisLinesChartController: BaseLinesChartController {
    class GraphController {
        let mainLinesRenderer = LinesChartRenderer()
        let verticalScalesRenderer = VerticalScalesRenderer()
        let lineBulletsRenerer = LineBulletsRenerer()
        let previewLinesRenderer = LinesChartRenderer()
        
        var chartLines: [LinesChartRenderer.LineData] = []

        var totalVerticalRange: ClosedRange<CGFloat> = Constants.defaultRange

        init() {
            self.mainLinesRenderer.lineWidth = 2
            self.previewLinesRenderer.lineWidth = 1
            self.lineBulletsRenerer.isEnabled = false
            
            self.mainLinesRenderer.optimizationLevel = BaseConstants.linesChartOptimizationLevel
            self.previewLinesRenderer.optimizationLevel = BaseConstants.previewLinesChartOptimizationLevel
        }
        
        func updateMainChartVerticalRange(range: ClosedRange<CGFloat>, animated: Bool) {
            mainLinesRenderer.setup(verticalRange: range, animated: animated)
            verticalScalesRenderer.setup(verticalRange: range, animated: animated)
            lineBulletsRenerer.setup(verticalRange: range, animated: animated)
        }
    }
    
    private var graphControllers: [GraphController] = []
    private let verticalLineRenderer = VerticalLinesRenderer()
    private let horizontalScalesRenderer = HorizontalScalesRenderer()

    var totalHorizontalRange: ClosedRange<CGFloat> = Constants.defaultRange

    private let initialChartCollection: ChartsCollection
    
    private var prevoiusHorizontalStrideInterval: Int = 1
    
    override init(chartsCollection: ChartsCollection) {
        self.initialChartCollection = chartsCollection
        graphControllers = chartsCollection.chartValues.map { _ in GraphController() }

        super.init(chartsCollection: chartsCollection)
        self.zoomChartVisibility = chartVisibility
    }
    
    override func setupChartCollection(chartsCollection: ChartsCollection, animated: Bool, isZoomed: Bool) {
        super.setupChartCollection(chartsCollection: chartsCollection, animated: animated, isZoomed: isZoomed)
        
        for (index, controller) in self.graphControllers.enumerated() {
            let chart = chartsCollection.chartValues[index]
            let points = chart.values.enumerated().map({ (arg) -> CGPoint in
                return CGPoint(x: chartsCollection.axisValues[arg.offset].timeIntervalSince1970,
                               y: arg.element)
            })
            let chartLines = [LinesChartRenderer.LineData(color: chart.color, points: points)]
            controller.chartLines = [LinesChartRenderer.LineData(color: chart.color, points: points)]
            controller.verticalScalesRenderer.labelsColor = chart.color
            controller.totalVerticalRange = LinesChartRenderer.LineData.verticalRange(lines: chartLines) ?? Constants.defaultRange
            self.totalHorizontalRange = LinesChartRenderer.LineData.horizontalRange(lines: chartLines) ?? Constants.defaultRange
            controller.lineBulletsRenerer.bullets = chartLines.map { LineBulletsRenerer.Bullet(coordinate: $0.points.first ?? .zero,
                                                                                               color: $0.color) }
            controller.previewLinesRenderer.setup(horizontalRange: self.totalHorizontalRange, animated: animated)
            controller.previewLinesRenderer.setup(verticalRange: controller.totalVerticalRange, animated: animated)
            controller.mainLinesRenderer.setLines(lines: chartLines, animated: animated)
            controller.previewLinesRenderer.setLines(lines: chartLines, animated: animated)
            
            controller.verticalScalesRenderer.setHorizontalLinesVisible((index == 0), animated: animated)
            controller.verticalScalesRenderer.isRightAligned = (index != 0)
        }
        
        self.prevoiusHorizontalStrideInterval = -1
        
        let chartRange: ClosedRange<CGFloat>
        if isZoomed {
            chartRange = zoomedChartRange
        } else {
            chartRange = initialChartRange
        }
        
        updateHorizontalLimists(horizontalRange: chartRange, animated: animated)
        updateMainChartHorizontalRange(range: chartRange, animated: animated)
        updateVerticalLimitsAndRange(horizontalRange: chartRange, animated: animated)
        
        self.chartRangeUpdatedClosure?(currentChartHorizontalRangeFraction, animated)
    }
    
    override func initializeChart() {
        if let first = initialChartCollection.axisValues.first?.timeIntervalSince1970,
            let last = initialChartCollection.axisValues.last?.timeIntervalSince1970 {
            initialChartRange = CGFloat(max(first, last - BaseConstants.defaultRangePresetLength))...CGFloat(last)
        }
        setupChartCollection(chartsCollection: initialChartCollection, animated: false, isZoomed: false)
    }
    
    override var mainChartRenderers: [ChartViewRenderer] {
        return graphControllers.map { $0.mainLinesRenderer } +
               graphControllers.flatMap { [$0.verticalScalesRenderer, $0.lineBulletsRenerer] } +
            [horizontalScalesRenderer, verticalLineRenderer,
//             performanceRenderer
        ]
    }
    
    override var navigationRenderers: [ChartViewRenderer] {
        return graphControllers.map { $0.previewLinesRenderer }
    }
    
    override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        chartVisibility = visibility
        zoomChartVisibility = visibility
        let firstIndex = visibility.firstIndex(where: { $0 })
        for (index, isVisible) in visibility.enumerated() {
            let graph = graphControllers[index]
            for graphIndex in graph.chartLines.indices {
                graph.mainLinesRenderer.setLineVisible(isVisible, at: graphIndex, animated: animated)
                graph.previewLinesRenderer.setLineVisible(isVisible, at: graphIndex, animated: animated)
                graph.lineBulletsRenerer.setLineVisible(isVisible, at: graphIndex, animated: animated)
            }
            graph.verticalScalesRenderer.setVisible(isVisible, animated: animated)
            if let firstIndex = firstIndex {
                graph.verticalScalesRenderer.setHorizontalLinesVisible(index == firstIndex, animated: animated)
            }
        }
        
        updateVerticalLimitsAndRange(horizontalRange: currentHorizontalRange, animated: true)
        
        if isChartInteractionBegun {
            chartInteractionDidBegin(point: lastChartInteractionPoint)
        }
    }
    
    override func chartInteractionDidBegin(point: CGPoint) {
        let horizontalRange = currentHorizontalRange
        let chartFrame = self.chartFrame()
        guard chartFrame.width > 0 else { return }
        
        let dateToFind = Date(timeIntervalSince1970: TimeInterval(horizontalRange.distance * point.x + horizontalRange.lowerBound))
        guard let (closestDate, minIndex) = findClosestDateTo(dateToFind: dateToFind) else { return }
        
        let chartInteractionWasBegin = isChartInteractionBegun
        super.chartInteractionDidBegin(point: point)
        
        for graphController in graphControllers {
            graphController.lineBulletsRenerer.bullets = graphController.chartLines.map { chart in
                LineBulletsRenerer.Bullet(coordinate: chart.points[minIndex], color: chart.color)
            }
            graphController.lineBulletsRenerer.isEnabled = true
        }
        
        let chartValue: CGFloat = CGFloat(closestDate.timeIntervalSince1970)
        let detailsViewPosition = (chartValue - horizontalRange.lowerBound) / horizontalRange.distance * chartFrame.width + chartFrame.minX
        self.setDetailsViewModel?(chartDetailsViewModel(closestDate: closestDate, pointIndex: minIndex), chartInteractionWasBegin)
        self.setDetailsChartVisibleClosure?(true, true)
        self.setDetailsViewPositionClosure?(detailsViewPosition)
        self.verticalLineRenderer.values = [chartValue]
    }
    
    override var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        let lowerPercent = (currentHorizontalRange.lowerBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        let upperPercent = (currentHorizontalRange.upperBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        return lowerPercent...upperPercent
    }
    
    override var currentHorizontalRange: ClosedRange<CGFloat> {
        return graphControllers.first?.mainLinesRenderer.horizontalRange.end ?? Constants.defaultRange
    }

    override func cancelChartInteraction() {
        super.cancelChartInteraction()
        for graphController in graphControllers {
            graphController.lineBulletsRenerer.isEnabled = false
        }
        
        self.setDetailsChartVisibleClosure?(false, true)
        self.verticalLineRenderer.values = []
    }
    
    override func didTapZoomOut() {
        cancelChartInteraction()
        self.setupChartCollection(chartsCollection: initialChartCollection, animated: true, isZoomed: false)
    }
    
    override func updateChartRange(_ rangeFraction: ClosedRange<CGFloat>) {
        cancelChartInteraction()
        
        let horizontalRange = ClosedRange(uncheckedBounds:
            (lower: totalHorizontalRange.lowerBound + rangeFraction.lowerBound * totalHorizontalRange.distance,
             upper: totalHorizontalRange.lowerBound + rangeFraction.upperBound * totalHorizontalRange.distance))
        
        if isZoomed {
            zoomedChartRange = horizontalRange
        } else {
            initialChartRange = horizontalRange
        }
        updateChartRangeTitle(animated: true)
        
        updateMainChartHorizontalRange(range: horizontalRange, animated: false)
        updateHorizontalLimists(horizontalRange: horizontalRange, animated: true)
        updateVerticalLimitsAndRange(horizontalRange: horizontalRange, animated: true)
    }
    
    func updateMainChartHorizontalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        for controller in graphControllers {
            controller.mainLinesRenderer.setup(horizontalRange: range, animated: animated)
            controller.verticalScalesRenderer.setup(horizontalRange: range, animated: animated)
            controller.lineBulletsRenerer.setup(horizontalRange: range, animated: animated)
        }
        horizontalScalesRenderer.setup(horizontalRange: range, animated: animated)
        verticalLineRenderer.setup(horizontalRange: range, animated: animated)
    }
    
    func updateHorizontalLimists(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        if let (stride, labels) = horizontalLimitsLabels(horizontalRange: horizontalRange,
                                                         scaleType: isZoomed ? .hour : .day,
                                                         prevoiusHorizontalStrideInterval: prevoiusHorizontalStrideInterval) {
            self.horizontalScalesRenderer.setup(labels: labels, animated: animated)
            self.prevoiusHorizontalStrideInterval = stride
        }
    }
    
    func updateVerticalLimitsAndRange(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        let chartHeight = chartFrame().height
        let approximateNumberOfChartValues = (chartHeight / BaseConstants.minimumAxisYLabelsDistance)

        var dividorsAndMultiplers: [(startValue: CGFloat, base: CGFloat, count: Int, maximumNumberOfDecimals: Int)] = graphControllers.enumerated().map { arg in
            let (index, controller) = arg
            let verticalRange = LinesChartRenderer.LineData.verticalRange(lines: controller.chartLines,
                                                                          calculatingRange: horizontalRange,
                                                                          addBounds: true) ?? controller.totalVerticalRange

            var numberOfOffsetsPerItem = verticalRange.distance / approximateNumberOfChartValues
            
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

            let generalBase = Constants.verticalBaseAnchors.first { numberOfOffsetsPerItem > $0 } ?? BaseConstants.defaultVerticalBaseAnchor
            let base = generalBase * multiplier / dividor
            
            var verticalValue = (verticalRange.lowerBound / base).rounded(.down) * base
            let startValue = verticalValue
            var count = 0
            if chartVisibility[index] {
                while verticalValue < verticalRange.upperBound {
                    count += 1
                    verticalValue += base
                }
            }
            return (startValue: startValue, base: base, count: count, maximumNumberOfDecimals: maximumNumberOfDecimals)
        }
        
        let totalCount = dividorsAndMultiplers.map { $0.count }.max() ?? 0
        guard totalCount > 0 else { return }
        
        let numberFormatter = BaseConstants.chartNumberFormatter
        for (index, controller) in graphControllers.enumerated() {
            
            let (startValue, base, _, maximumNumberOfDecimals) = dividorsAndMultiplers[index]
            
            let updatedRange = startValue...(startValue + base * CGFloat(totalCount))
            if controller.verticalScalesRenderer.verticalRange.end != updatedRange {
                numberFormatter.maximumFractionDigits = maximumNumberOfDecimals

                var verticalLabels: [LinesChartLabel] = []
                for multipler in 0...(totalCount - 1) {
                    let verticalValue = startValue + base * CGFloat(multipler)
                    let text: String = numberFormatter.string(from: NSNumber(value: Double(verticalValue))) ?? ""
                    verticalLabels.append(LinesChartLabel(value: verticalValue, text: text))
                }
                
                controller.verticalScalesRenderer.setup(verticalLimitsLabels: verticalLabels, animated: animated)
                controller.updateMainChartVerticalRange(range: updatedRange, animated: animated)
            }
        }
    }
    
    override func apply(colorMode: ColorMode, animated: Bool) {
        horizontalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalLineRenderer.linesColor = colorMode.chartStrongLinesColor

        for controller in graphControllers {
            controller.verticalScalesRenderer.horizontalLinesColor = colorMode.chartHelperLinesColor
            controller.lineBulletsRenerer.setInnerColor(colorMode.chartBackgroundColor, animated: animated)
            controller.verticalScalesRenderer.axisXColor = colorMode.chartStrongLinesColor
        }
    }
}
