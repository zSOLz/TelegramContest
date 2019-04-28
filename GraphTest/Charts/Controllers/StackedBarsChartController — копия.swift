//
//  StackedBarsChartController.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit

private enum Constants {
    static let defaultRange: ClosedRange<CGFloat> = 0...1
}

class StackedBarsChartController: BaseChartController {
    private let initialChartCollection: ChartsCollection
    
    // TODO: Начинать анимацию с выбранной плашки
    // TODO: Рендерить столбики по середине, и не сбоку
    // TODO: Убирать ненужные столбики если это можно
    // TODO: На экране Preview дёргается рэнж в конце
    // TODO: Ease In/Out работают с рывком в конце
    private let mainBarsRenderer = BarChartRenderer()
    private let zoomedLinesRenderer = LinesChartRenderer()
    private let horizontalScalesRenderer = HorizontalScalesRenderer()
    private let verticalScalesRenderer = VerticalScalesRenderer()
    private let verticalLineRenderer = VerticalLinesRenderer()
    private let lineBulletsRenerer = LineBulletsRenerer()
    private let chartDetailsRenderer = ChartDetailsRenderer()
    
    private let previewBarsChartRenderer = BarChartRenderer()
    private let zoomedPreviewLinesRenderer = LinesChartRenderer()
    
    private var totalVerticalRange: ClosedRange<CGFloat> = Constants.defaultRange
    private var totalHorizontalRange: ClosedRange<CGFloat> = Constants.defaultRange
    
    private var prevoiusHorizontalStrideInterval: Int = 1
    
    private (set) var chartLines: [LinesChartRenderer.LineData] = []
    private (set) var chartBars: BarChartRenderer.BarsData = BarChartRenderer.BarsData(barWidth: 1, locations: [], components: [])

    override init(chartsCollection: ChartsCollection) {
        self.initialChartCollection = chartsCollection
        self.zoomedLinesRenderer.lineWidth = 2
        
        self.zoomedLinesRenderer.optimizationLevel = BaseChartConstants.linesChartOptimizationLevel
        self.zoomedPreviewLinesRenderer.optimizationLevel = BaseChartConstants.previewLinesChartOptimizationLevel * 1.5

        self.chartLines = chartsCollection.chartValues.map { LinesChartRenderer.LineData(color: $0.color, points: []) }
        self.zoomedLinesRenderer.setLines(lines: chartLines, animated: false)
        self.zoomedPreviewLinesRenderer.setLines(lines: chartLines, animated: false)
        self.lineBulletsRenerer.bullets = self.chartLines.map { LineBulletsRenerer.Bullet(coordinate: $0.points.first ?? .zero,
                                                                                          color: $0.color)}

        self.lineBulletsRenerer.isEnabled = false
        self.verticalLineRenderer.isEnabled = false
        self.chartDetailsRenderer.setChartVisible(false, animated: false)

        super.init(chartsCollection: chartsCollection)
        self.zoomChartVisibility = chartVisibility
    }
    
    override func setupChartCollection(chartsCollection: ChartsCollection, animated: Bool, isZoomed: Bool) {
        super.setupChartCollection(chartsCollection: chartsCollection, animated: animated, isZoomed: isZoomed)
        
        let chartRange: ClosedRange<CGFloat>

        if isZoomed {
            self.chartLines = chartsCollection.chartValues.map { chart in
                let points = chart.values.enumerated().map({ (arg) -> CGPoint in
                    return CGPoint(x: chartsCollection.axisValues[arg.offset].timeIntervalSince1970,
                                   y: arg.element)
                })
                return LinesChartRenderer.LineData(color: chart.color, points: points)
            }
            
            self.prevoiusHorizontalStrideInterval = -1
            self.totalVerticalRange = LinesChartRenderer.LineData.verticalRange(lines: chartLines) ?? Constants.defaultRange
            self.totalHorizontalRange = LinesChartRenderer.LineData.horizontalRange(lines: chartLines) ?? Constants.defaultRange

            chartRange = zoomedChartRange

            self.zoomedLinesRenderer.setLines(lines: chartLines, animated: false)
            self.zoomedPreviewLinesRenderer.setLines(lines: chartLines, animated: false)
            
            self.mainBarsRenderer.setChartVisible(false, animated: animated)
            self.previewBarsChartRenderer.setChartVisible(false, animated: animated)
            self.zoomedLinesRenderer.setChartVisible(true, animated: animated)
            self.zoomedPreviewLinesRenderer.setChartVisible(true, animated: animated)
            
            if let range = LinesChartRenderer.LineData.verticalRange(lines: visibleCharts,
                                                                     calculatingRange: chartRange,
                                                                     addBounds: true) {
                let (range, _) = verticalLimitsLabels(verticalRange: range)
                zoomedLinesRenderer.setup(verticalRange: range, animated: false)
            }
        } else {
            let width: CGFloat
            if chartsCollection.axisValues.count > 1 {
                width = CGFloat(abs(chartsCollection.axisValues[1].timeIntervalSince1970 - chartsCollection.axisValues[0].timeIntervalSince1970))
            } else {
                width = 1
            }
            let components = chartsCollection.chartValues.map { BarChartRenderer.BarsData.Component(color: $0.color,
                                                                                                    values: $0.values.map { CGFloat($0) }) }
            self.chartBars = BarChartRenderer.BarsData(barWidth: width,
                                                       locations: chartsCollection.axisValues.map { CGFloat($0.timeIntervalSince1970) },
                                                       components: components)
            
            self.totalVerticalRange = BarChartRenderer.BarsData.verticalRange(bars: self.chartBars) ?? Constants.defaultRange
            let totalHorizontalRange = BarChartRenderer.BarsData.horizontalRange(bars: self.chartBars) ?? Constants.defaultRange
            self.totalHorizontalRange = (totalHorizontalRange.lowerBound - width)...(totalHorizontalRange.upperBound)
            
            self.previewBarsChartRenderer.bars = self.chartBars
            self.mainBarsRenderer.bars = self.chartBars
            
            chartRange = initialChartRange
            
            self.mainBarsRenderer.setChartVisible(true, animated: animated)
            self.previewBarsChartRenderer.setChartVisible(true, animated: animated)
            self.zoomedLinesRenderer.setChartVisible(false, animated: animated)
            self.zoomedPreviewLinesRenderer.setChartVisible(false, animated: animated)
            
            if let range = BarChartRenderer.BarsData.verticalRange(bars: visibleBars,
                                                                   calculatingRange: chartRange,
                                                                   addBounds: true) {
                let (range, _) = verticalLimitsLabels(verticalRange: range)
                mainBarsRenderer.setup(verticalRange: range, animated: animated)
            }
        }
        
        self.previewBarsChartRenderer.setup(horizontalRange: self.totalHorizontalRange, animated: animated)
        self.zoomedPreviewLinesRenderer.setup(horizontalRange: self.totalHorizontalRange, animated: animated)
        self.updatePreviewVerticalLimitsAndRange(horizontalRange: self.totalHorizontalRange, animated: animated)
        
        updateHorizontalLimists(horizontalRange: chartRange, animated: animated)
        updateMainChartHorizontalRange(range: chartRange, animated: animated)
        updateVerticalLimitsAndRange(horizontalRange: chartRange, animated: animated)
        
        self.chartRangeUpdatedClosure?(currentChartHorizontalRangeFraction, animated)
    }
    
    override func initializeChart() {
        if let first = initialChartCollection.axisValues.first?.timeIntervalSince1970,
            let last = initialChartCollection.axisValues.last?.timeIntervalSince1970 {
            initialChartRange = CGFloat(max(first, last - BaseChartConstants.defaultRangePresetLength))...CGFloat(last)
        }
        setupChartCollection(chartsCollection: initialChartCollection, animated: false, isZoomed: false)
    }
    
    override var mainChartRenderers: [ChartViewRenderer] {
        return [performanceRenderer,
                mainBarsRenderer,
                zoomedLinesRenderer,
                horizontalScalesRenderer,
                verticalScalesRenderer,
                verticalLineRenderer,
                lineBulletsRenerer,
                chartDetailsRenderer]
    }
    
    override var navigationRenderers: [ChartViewRenderer] {
        return [previewBarsChartRenderer,
                zoomedPreviewLinesRenderer]
    }
    
    override func updateChartsVisibility(visibility: [Bool], animated: Bool) {
        chartVisibility = visibility
        zoomChartVisibility = visibility
        for (index, isVisible) in visibility.enumerated() {
            mainBarsRenderer.setComponentVisible(isVisible, at: index, animated: animated)
            zoomedLinesRenderer.setLineVisible(isVisible, at: index, animated: animated)
            lineBulletsRenerer.setLineVisible(isVisible, at: index, animated: animated)
//            previewBarsChartRenderer.setComponentVisible(isVisible, at: index, animated: animated)
            zoomedPreviewLinesRenderer.setLineVisible(isVisible, at: index, animated: animated)
        }
        
        updateVerticalLimitsAndRange(horizontalRange: currentHorizontalRange, animated: true)
        updatePreviewVerticalLimitsAndRange(horizontalRange: self.totalHorizontalRange, animated: true)
        if isChartInteractionBegun {
            chartInteractionDidBegin(point: lastChartInteractionPoint)
        }
    }
    
    var isChartDetailsRendererTapped: Bool = false
    var isChartDetailsSelectedDate: Date? = nil
    override func chartInteractionDidBegin(point: CGPoint) {
        super.chartInteractionDidBegin(point: point)
        let horizontalRange = mainBarsRenderer.horizontalRange.current
        let chartFrame = self.chartFrame()
        guard chartFrame.width > 0 else { return }
        
        let dateToFind = Date(timeIntervalSince1970: TimeInterval(horizontalRange.distance * point.x + horizontalRange.lowerBound))
        guard let (closestDate, minIndex) = findClosestDateTo(dateToFind: dateToFind) else { return }

        let chartPoint = chartFrame.origin + point * chartFrame.size
        if chartDetailsRenderer.previousRenderBannerFrame.contains(chartPoint) {
            isChartDetailsRendererTapped = true
            return
        }
        isChartDetailsRendererTapped = false
        isChartDetailsSelectedDate = closestDate

        super.chartInteractionDidBegin(point: point)
        
        let chartValue: CGFloat = CGFloat(closestDate.timeIntervalSince1970)
        let offset = isZoomed ? 0 : chartBars.barWidth / 2
        let detailsViewPosition = (chartValue - offset - horizontalRange.lowerBound) / horizontalRange.distance * chartFrame.width + chartFrame.minX

        self.chartDetailsRenderer.detailsViewModel = chartDetailsViewModel(closestDate: closestDate, pointIndex: minIndex)
        self.chartDetailsRenderer.setChartVisible(true, animated: true)
        self.chartDetailsRenderer.detailsViewPosition = detailsViewPosition
        
        if isZoomed {
            self.lineBulletsRenerer.bullets = chartLines.compactMap { chart in
                return LineBulletsRenerer.Bullet(coordinate: chart.points[minIndex], color: chart.color)
            }
            self.lineBulletsRenerer.isEnabled = true
            self.verticalLineRenderer.isEnabled = true
            self.verticalLineRenderer.values = [chartValue]
        } else {
            self.mainBarsRenderer.setSlectedIndex(minIndex, animated: true)
        }
    }
    
    override func chartInteractionDidEnd() {
        if isChartDetailsRendererTapped, let date = isChartDetailsSelectedDate {
            didTapZoomIn(date: date)
            cancelChartInteraction()
        }
    }
    
    override var currentChartHorizontalRangeFraction: ClosedRange<CGFloat> {
        let lowerPercent = (currentHorizontalRange.lowerBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        let upperPercent = (currentHorizontalRange.upperBound - totalHorizontalRange.lowerBound) / totalHorizontalRange.distance
        return lowerPercent...upperPercent
    }
    
    override var currentHorizontalRange: ClosedRange<CGFloat> {
        return mainBarsRenderer.horizontalRange.end
    }
    
    override func cancelChartInteraction() {
        super.cancelChartInteraction()
        isChartDetailsRendererTapped = false

        self.mainBarsRenderer.setSlectedIndex(nil, animated: true)
        self.lineBulletsRenerer.isEnabled = false
        self.verticalLineRenderer.isEnabled = false

        self.chartDetailsRenderer.setChartVisible(false, animated: true)
        self.verticalLineRenderer.values = []
    }
    
    override func didTapZoomIn(date: Date) {
        guard isZoomed == false else { return }
        cancelChartInteraction()
        self.getDetailsData?(date, { updatedCollection in
            if let updatedCollection = updatedCollection {
                self.initialChartRange = self.currentHorizontalRange
                self.zoomedChartRange = CGFloat(date.timeIntervalSince1970)...CGFloat(date.timeIntervalSince1970 + .day)
                self.setupChartCollection(chartsCollection: updatedCollection, animated: true, isZoomed: true)
            }
        })
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
            updateChartRangeTitle(animated: true)
        } else {
            initialChartRange = horizontalRange
        }
        
        // TODO: Короткая анимация и края спрара/слева считать за границы
        updateMainChartHorizontalRange(range: horizontalRange, animated: false)
        updateHorizontalLimists(horizontalRange: horizontalRange, animated: true)
        updateVerticalLimitsAndRange(horizontalRange: horizontalRange, animated: true)
    }
    
    func updateMainChartHorizontalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        mainBarsRenderer.setup(horizontalRange: range, animated: animated)
        zoomedLinesRenderer.setup(horizontalRange: range, animated: animated)
        horizontalScalesRenderer.setup(horizontalRange: range, animated: animated)
        verticalScalesRenderer.setup(horizontalRange: range, animated: animated)
        verticalLineRenderer.setup(horizontalRange: range, animated: animated)
        lineBulletsRenerer.setup(horizontalRange: range, animated: animated)
        chartDetailsRenderer.setup(horizontalRange: range, animated: animated)
    }
    
    func updateHorizontalLimists(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        if let (stride, labels) = horizontalLimitsLabels(horizontalRange: horizontalRange,
                                                         scaleType: isZoomed ? .hour : .day,
                                                         prevoiusHorizontalStrideInterval: prevoiusHorizontalStrideInterval) {
            self.horizontalScalesRenderer.setup(labels: labels, animated: animated)
            self.prevoiusHorizontalStrideInterval = stride
        }
    }
    
    var visibleCharts: [LinesChartRenderer.LineData] {
        let visibleCharts: [LinesChartRenderer.LineData] = zoomChartVisibility.enumerated().compactMap { args in
            args.element ? chartLines[args.offset] : nil
        }
        return visibleCharts
    }
    
    var visibleBars: BarChartRenderer.BarsData {
        let visibleComponents: [BarChartRenderer.BarsData.Component] = chartVisibility.enumerated().compactMap { args in
            args.element ? chartBars.components[args.offset] : nil
        }
        return BarChartRenderer.BarsData(barWidth: chartBars.barWidth,
                                         locations: chartBars.locations,
                                         components: visibleComponents)
    }

    func updateVerticalLimitsAndRange(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        if isZoomed {
            if let range = LinesChartRenderer.LineData.verticalRange(lines: visibleCharts,
                                                                     calculatingRange: horizontalRange,
                                                                     addBounds: true) {
                let (range, labels) = verticalLimitsLabels(verticalRange: range)
                if verticalScalesRenderer.verticalRange.end != range {
                    verticalScalesRenderer.setup(verticalLimitsLabels: labels, animated: animated)
                }
                updateZoomedChartVerticalRange(range: range, animated: animated)
            }
        } else {
            if let range = BarChartRenderer.BarsData.verticalRange(bars: visibleBars,
                                                                   calculatingRange: horizontalRange,
                                                                   addBounds: true) {
                let (range, labels) = verticalLimitsLabels(verticalRange: range)
                if verticalScalesRenderer.verticalRange.end != range && !isZoomed {
                    verticalScalesRenderer.setup(verticalLimitsLabels: labels, animated: animated)
                }
                
                updateMainChartVerticalRange(range: range, animated: animated)
            }
        }
    }
    
    func updatePreviewVerticalLimitsAndRange(horizontalRange: ClosedRange<CGFloat>, animated: Bool) {
        if let range = LinesChartRenderer.LineData.verticalRange(lines: visibleCharts,
                                                                 calculatingRange: horizontalRange,
                                                                 addBounds: true) {
            zoomedPreviewLinesRenderer.setup(verticalRange: range, animated: animated)
        }
        if let range = BarChartRenderer.BarsData.verticalRange(bars: visibleBars,
                                                               calculatingRange: horizontalRange,
                                                               addBounds: true) {
            previewBarsChartRenderer.setup(verticalRange: range, animated: animated)
        }
    }
    
    func updateMainChartVerticalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        mainBarsRenderer.setup(verticalRange: range, animated: animated)
        horizontalScalesRenderer.setup(verticalRange: range, animated: animated)
        verticalScalesRenderer.setup(verticalRange: range, animated: animated)
    }
    
    func updateZoomedChartVerticalRange(range: ClosedRange<CGFloat>, animated: Bool) {
        zoomedLinesRenderer.setup(verticalRange: range, animated: animated)
        horizontalScalesRenderer.setup(verticalRange: range, animated: animated)
        verticalScalesRenderer.setup(verticalRange: range, animated: animated)
        verticalLineRenderer.setup(verticalRange: range, animated: animated)
        lineBulletsRenerer.setup(verticalRange: range, animated: animated)
    }

    override func apply(colorMode: ColorMode, animated: Bool) {
        horizontalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalScalesRenderer.labelsColor = colorMode.chartLabelsColor
        verticalScalesRenderer.axisXColor = colorMode.chartStrongLinesColor
        verticalScalesRenderer.horizontalLinesColor = colorMode.chartHelperLinesColor
        lineBulletsRenerer.innerColor = colorMode.chartBackgroundColor
        verticalLineRenderer.linesColor = colorMode.chartStrongLinesColor
        chartDetailsRenderer.apply(colorMode: colorMode, animated: animated)
    }
}
