//
//  OrbitPagerView.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 17/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit

/// An array of category tuples, a name and count pair
typealias CategoryCounts = [(String, Int)]

struct OrbitPagerSettings {
    /// The page marker image for an item (in UIPageControl, a dot)
    static let itemImage = UIImage(
        systemName: "circle.fill",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 7
        )
    )
    
    /// The add new page marker image
    static let addImage = UIImage(
        systemName: "plus",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 10,
            weight: .black
        )
    )
    
    static let pageWidth: CGFloat = 14
    static let borderWidth: CGFloat = 1
    static let pageTopSpacing: CGFloat = 2
    static let labelTopSpacing: CGFloat = 4
    static let labelLeftSpacing: CGFloat = 3
    static let emphasiseSelectedLabel = true
    static let expandSelectedLabel = false
    static let trimNameWhenUnselected = true
}

/// Akin to UIPageControl, OrbitPagerView displays a row of dots corresponding to pages. However here, these dots are sectioned into categories, and each section has an 'add new' page at the end.
class OrbitPagerView: UIView {
    /// The overall page index currently selected
    var pageIndex: Int = 0 {
        didSet {
            var pageIndexRemaining: Int? = pageIndex
            for categoryView in categoryViews {
                if pageIndexRemaining != nil {
                    if pageIndexRemaining! < categoryView.pageCount
                    {
                        categoryView.pageIndex = pageIndexRemaining!
                        pageIndexRemaining = nil
                    } else {
                        categoryView.pageIndex = nil
                        pageIndexRemaining! -= categoryView.pageCount
                    }
                } else {
                    categoryView.pageIndex = nil
                }
            }
        }
    }
    
    /// The set of page indexes that are 'add new' pages
    var addNewPageIndexes: IndexSet {
        get {
            var indexes: [Int] = []
            var categoryStartCount = 0
            for categoryView in categoryViews {
                indexes.append(categoryStartCount + categoryView.pageCount - 1)
                categoryStartCount += categoryView.pageCount
            }
            return IndexSet(indexes)
        }
    }
    
    /// The page index for the 'add new' page of the category containing the currently selected page
    var pageIndexForCurrentAddNew: Int? {
        get {
            var categoryStartCount = 0
            for categoryView in categoryViews {
                if categoryView.pageIndex != nil {
                    return categoryStartCount + categoryView.pageCount - 1
                }
                categoryStartCount += categoryView.pageCount
            }
            return nil
        }
    }
    
    /// The page index corresponding to the category, and index within that category
    func pageIndexFor(category: String, index: Int) -> Int? {
        var categoryStartCount = 0
        for categoryView in categoryViews {
            if categoryView.name == category {
                return categoryStartCount + index
            }
            categoryStartCount += categoryView.pageCount
        }
        return nil
    }
    
    /// The name of the category containing the currently selected page
    var currentCategoryName: String? {
        get {
            for categoryView in categoryViews {
                if categoryView.pageIndex != nil {
                    return categoryView.name
                }
            }
            return nil
        }
    }
    
    /// The index within the category of the currently selected page
    var currentCategoryIndex: Int? {
        get {
            for categoryView in categoryViews {
                if let index = categoryView.pageIndex {
                    return index
                }
            }
            return nil
        }
    }
    
    /// The total number of pages
    var pageCount: Int {
        get { categoryViews.reduce(0) { $0 + $1.pageCount} }
    }
    
    /// The index within the category corresponding to the overall page index
    func categoryIndex(pageIndex: Int) -> (String, Int)? {
        var categoryStartIndex = 0
        for categoryView in categoryViews {
            if pageIndex >= categoryStartIndex && pageIndex < categoryStartIndex + categoryView.itemCount {
                return (categoryView.name, pageIndex - categoryStartIndex)
            }
            categoryStartIndex += categoryView.pageCount
        }
        return nil
    }
    
    /// The categories and corresponding counts to display
    var categoryCounts: CategoryCounts {
        set {
            // Add or update category views
            for (index, (name, count)) in newValue.enumerated() {
                if !stack.arrangedSubviews.indices.contains(index) {
                    stack.insertArrangedSubview(OrbitPagerCategoryView(), at: index)
                }
                let categoryView = categoryViews[index]
                categoryView.name = name
                categoryView.itemCount = count
            }
            // Remove extra category views
            while stack.arrangedSubviews.count > newValue.count {
                let view = stack.arrangedSubviews.last!
                stack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            layoutIfNeeded()
        }
        get {
            categoryViews.map { ($0.name, $0.itemCount)}
        }
    }
    
    override init (frame: CGRect) {
        super.init(frame: frame)
        initCommon()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initCommon()
    }
    
    private func initCommon() {
        translatesAutoresizingMaskIntoConstraints = false
        let width = widthAnchor.constraint(equalToConstant: 0)
        width.priority = UILayoutPriority(rawValue: 999)
        width.isActive = true
        
        stack.axis = .horizontal
        stack.spacing = OrbitPagerSettings.labelLeftSpacing
        stack.distribution = .fillProportionally
        stack.alignment = .center
        
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.topAnchor.constraint(equalTo: topAnchor).isActive = true
        stack.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        stack.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        stack.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
    }
    
    private let stack = UIStackView()
    private var categoryViews: [OrbitPagerCategoryView] {
        get { stack.arrangedSubviews as! [OrbitPagerCategoryView] }
    }
}

fileprivate class OrbitPagerCategoryView: UIView {
    var name: String = "" {
        didSet {
            categoryLabel.text = name
            layoutIfNeeded()
        }
    }

    var itemCount: Int = 0 {
        didSet {
            while pageStackViews.count - addNewCount < itemCount {
                guard let itemImage = OrbitPagerSettings.itemImage
                else { fatalError("Cannot get item image") }
                pageStack.insertArrangedSubview(OrbitPagerPageView(image: itemImage), at: 0)
            }
            while pageStackViews.count - addNewCount > itemCount {
                let view = pageStack.arrangedSubviews[0]
                pageStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            layoutIfNeeded()
        }
    }
    
    var pageCount: Int {
        get {
            itemCount + addNewCount
        }
    }
    
    var pageIndex: Int? {
        didSet {
            for (index, view) in pageStackViews.enumerated() {
                view.color = (index == pageIndex) ? UIColor.label : UIColor.placeholderText
            }
            if OrbitPagerSettings.emphasiseSelectedLabel {
                categoryLabel.textColor = (pageIndex == nil) ? .placeholderText : .label
            }
            if OrbitPagerSettings.trimNameWhenUnselected {
                if let firstWord = self.name.split(separator: " ").first {
                    self.categoryLabel.text = (self.pageIndex == nil) ? String(firstWord) : self.name
                }
            }
            if OrbitPagerSettings.expandSelectedLabel {
                self.categoryLabel.setContentCompressionResistancePriority(
                    (self.pageIndex == nil) ? .defaultLow : .required,
                    for: .horizontal
                )
            }
            if OrbitPagerSettings.trimNameWhenUnselected || OrbitPagerSettings.expandSelectedLabel {
                UIView.animate(withDuration: 0.3) {
                    self.superview!.layoutIfNeeded()
                }
            }
        }
    }
    
    override init (frame: CGRect) {
        super.init(frame: frame)
        initCommon()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initCommon()
    }
    
    func initCommon() {
        borderView.backgroundColor = UIColor.placeholderText
        
        pageStack.axis = .horizontal
        pageStack.spacing = 0
        pageStack.distribution = .equalCentering
        pageStack.alignment = .center
        
        guard let addImage = OrbitPagerSettings.addImage
        else { fatalError("Cannot get add image") }
        pageStack.addArrangedSubview(OrbitPagerPageView(image: addImage))
        
        categoryLabel.lineBreakMode = .byClipping
        
        translatesAutoresizingMaskIntoConstraints = false
        borderView.translatesAutoresizingMaskIntoConstraints = false
        pageStack.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(borderView)
        addSubview(pageStack)
        addSubview(categoryLabel)
        
        let constraints = [
            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.topAnchor.constraint(equalTo: topAnchor),
            borderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            borderView.widthAnchor.constraint(equalToConstant: OrbitPagerSettings.borderWidth),
            
            pageStack.leadingAnchor.constraint(equalTo: borderView.trailingAnchor),
            pageStack.topAnchor.constraint(equalTo: topAnchor, constant: OrbitPagerSettings.pageTopSpacing),
            pageStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            
            categoryLabel.leadingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: OrbitPagerSettings.labelLeftSpacing),
            categoryLabel.topAnchor.constraint(equalTo: pageStack.bottomAnchor, constant: OrbitPagerSettings.labelTopSpacing),
            categoryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            categoryLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        
        let breakableConstraints = [
            widthAnchor.constraint(equalToConstant: 0)
        ]
        breakableConstraints.forEach { $0.priority = .init(rawValue: 750) }
        NSLayoutConstraint.activate(breakableConstraints)
        
        categoryLabel.setContentCompressionResistancePriority(OrbitPagerSettings.expandSelectedLabel ? .defaultLow : .required, for: .horizontal)
    }
    
    private let addNewCount = 1
    private var borderView = UIView()
    private var pageStack = UIStackView()
    private var categoryLabel = UILabel()
    
    private var pageStackViews: [OrbitPagerPageView] {
        pageStack.arrangedSubviews as! [OrbitPagerPageView]
    }
}

fileprivate class OrbitPagerPageView: UIView {
    let imageView: UIImageView
    
    var color: UIColor {
        didSet {
            imageView.tintColor = color
        }
    }
    
    init(image: UIImage) {
        imageView = UIImageView(image: image)
        color = UIColor.placeholderText // init value w/o didSet
        defer { color = UIColor.placeholderText } // trigger didSet
        
        super.init(frame: CGRect.zero)
        
        addSubview(imageView)
        
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        widthAnchor.constraint(equalToConstant: OrbitPagerSettings.pageWidth).isActive = true
        
        imageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        imageView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
