//
//  OrbitPagerView.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 17/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit

/// An array of category tuples, a name, item count and add count triplet
typealias CategoryCounts = [(name: String, item: Int, addNew: Int)]

struct OrbitPagerSettings {
    /// The page marker image for an item (in UIPageControl, a dot)
    static let itemImage = UIImage(
        systemName: "circle.fill",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 7,
            weight: .black
        )
    )
    
    /// The add new page marker image
    static let addImage = UIImage(
        systemName: "circle",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 7,
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
            // Animate any container
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.superview?.layoutIfNeeded()
            }
        }
    }
    
    /// The set of page indexes that are 'add new' pages
    var addNewPageIndexes: IndexSet {
        get {
            var currentIndex = 0
            var indexes: [Int] = []
            for categoryView in categoryViews {
                currentIndex += categoryView.itemCount
                for _ in 0..<categoryView.addNewCount {
                    indexes.append(currentIndex)
                    currentIndex += 1
                }
            }
            return IndexSet(indexes)
        }
    }
    
    /// The page index for the 'add new' page of the category containing the currently selected page
    var pageIndexForCurrentAddNew: Int? {
        get {
            var categoryStartIndex = 0
            for categoryView in categoryViews {
                if categoryView.pageIndex != nil {
                    return categoryView.addNewCount > 0 ? categoryStartIndex + categoryView.itemCount : nil
                }
                categoryStartIndex += categoryView.pageCount
            }
            return nil
        }
    }
    
    var pageRangesForCurrentCategory: (items: Range<Int>, addNew: Range<Int>)? {
        var categoryStartIndex = 0
        for categoryView in categoryViews {
            if categoryView.pageIndex != nil {
                let addNewStartIndex = categoryStartIndex + categoryView.itemCount
                return (categoryStartIndex..<addNewStartIndex, addNewStartIndex..<addNewStartIndex + categoryView.addNewCount)
            }
            categoryStartIndex += categoryView.pageCount
        }
        return nil
    }
    
    /// The page index corresponding to the category, and index within that category
    func pageIndexFor(category: String, index: Int) -> Int? {
        var categoryStartIndex = 0
        for categoryView in categoryViews {
            if categoryView.name == category {
                assert(index < categoryView.pageCount)
                return categoryStartIndex + index
            }
            categoryStartIndex += categoryView.pageCount
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
            for (index, (name, itemCount, addNewCount)) in newValue.enumerated() {
                if !stack.arrangedSubviews.indices.contains(index) {
                    stack.insertArrangedSubview(OrbitPagerCategoryView(), at: index)
                }
                let categoryView = categoryViews[index]
                categoryView.name = name
                categoryView.itemCount = itemCount
                categoryView.addNewCount = addNewCount
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
            categoryViews.map { ($0.name, $0.itemCount, $0.addNewCount)}
        }
    }
    
    /// A closure called when a right hand side tap outside of a category, or rightwards swipe is detected
    var actionNextPage: ( ()->Void )?
    
    /// A closure called when a left hand side tap outside of a category, or leftwards swipe is detected
    var actionPrevPage: ( ()->Void )?
    
    /// A closure called when a tap on a category view is detected, with the page index for the first item of that category
    var actionPage: ( (Int)->Void )?
    
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
        
        stack.axis = .horizontal
        stack.spacing = OrbitPagerSettings.labelLeftSpacing
        stack.distribution = .fillProportionally
        stack.alignment = .center
        
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.topAnchor.constraint(equalTo: topAnchor).isActive = true
        stack.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        stack.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        stack.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor).isActive = true
        stack.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor).isActive = true
        let width = stack.widthAnchor.constraint(equalToConstant: 0)
        width.priority = UILayoutPriority(rawValue: 999)
        width.isActive = true
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleGesture))
        let swipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleGesture))
        swipeLeftGestureRecognizer.direction = .left
        let swipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleGesture))
        swipeRightGestureRecognizer.direction = .right
        gestureRecognizers = [
            tapGestureRecognizer,
            swipeLeftGestureRecognizer,
            swipeRightGestureRecognizer
        ]
    }
    
    private let stack = UIStackView()
    private var categoryViews: [OrbitPagerCategoryView] {
        get { stack.arrangedSubviews as! [OrbitPagerCategoryView] }
    }
    
    @objc private func handleGesture(_ gestureRecognizer: UIGestureRecognizer) {
        guard
            gestureRecognizer.view != nil,
            let actionNextPage = actionNextPage,
            let actionPrevPage = actionPrevPage
        else
            { return }
        
        if let tapRecognizer = gestureRecognizer as? UITapGestureRecognizer,
           gestureRecognizer.state == .ended
        {
            // Is the tap on a category?
            for view in categoryViews {
                if view.frame.contains(tapRecognizer.location(in: self)),
                   let pageIndex = pageIndexFor(category: view.name, index: 0),
                   let actionPage = actionPage
                {
                    actionPage(pageIndex)
                    return
                }
            }
            // Otherwise, LHS vs RHS
            let isRHS = tapRecognizer.location(in: self).x > bounds.midX
            if isRHS {
                actionNextPage()
            } else {
                actionPrevPage()
            }
        }
        if let swipeRecognizer = gestureRecognizer as? UISwipeGestureRecognizer,
           gestureRecognizer.state == .ended
        {
            switch swipeRecognizer.direction {
            case .left:
                actionNextPage() // Swipes mimic direct interaction on supposed content not pager, e.g. swipe on carousel
            case .right:
                actionPrevPage()
            default:
                break
            }
        }
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
            while itemStackViews.count < itemCount {
                guard let itemImage = OrbitPagerSettings.itemImage
                else { fatalError("Cannot get item image") }
                itemStack.addArrangedSubview(OrbitPagerPageView(image: itemImage))
            }
            while itemStackViews.count > itemCount {
                let view = itemStack.arrangedSubviews[0]
                itemStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            if pageIndex != nil {
                displaySelectedInItems()
            }
            layoutIfNeeded()
        }
    }
    
    var addNewCount: Int = 1 {
        didSet {
            while addStackViews.count < addNewCount {
                guard let addImage = OrbitPagerSettings.addImage
                else { fatalError("Cannot get add image") }
                addStack.addArrangedSubview(OrbitPagerPageView(image: addImage))
            }
            while addStackViews.count > addNewCount {
                let view = addStack.arrangedSubviews[0]
                addStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            if pageIndex != nil {
                displaySelectedInAddNew()
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
            displaySelectedInItems()
            displaySelectedInAddNew()
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
    
    private func initCommon() {
        borderView.backgroundColor = UIColor.placeholderText
        
        categoryLabel.font = UIFont.preferredFont(forTextStyle: .body)
        categoryLabel.adjustsFontForContentSizeCategory = true
        
        itemStack.axis = .horizontal
        itemStack.spacing = 0
        itemStack.distribution = .equalCentering
        itemStack.alignment = .center
        addStack.axis = .horizontal
        addStack.spacing = 0
        addStack.distribution = .equalCentering
        addStack.alignment = .center
        
        categoryLabel.lineBreakMode = .byClipping
        
        translatesAutoresizingMaskIntoConstraints = false
        borderView.translatesAutoresizingMaskIntoConstraints = false
        itemStack.translatesAutoresizingMaskIntoConstraints = false
        addStack.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(borderView)
        addSubview(itemStack)
        addSubview(addStack)
        addSubview(categoryLabel)
        
        let constraints = [
            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.topAnchor.constraint(equalTo: topAnchor),
            borderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            borderView.widthAnchor.constraint(equalToConstant: OrbitPagerSettings.borderWidth),
            
            itemStack.leadingAnchor.constraint(equalTo: borderView.trailingAnchor),
            itemStack.topAnchor.constraint(equalTo: topAnchor, constant: OrbitPagerSettings.pageTopSpacing),
            
            addStack.leadingAnchor.constraint(equalTo: itemStack.trailingAnchor),
            addStack.topAnchor.constraint(equalTo: topAnchor, constant: OrbitPagerSettings.pageTopSpacing),
            addStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            
            categoryLabel.leadingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: OrbitPagerSettings.labelLeftSpacing),
            categoryLabel.topAnchor.constraint(greaterThanOrEqualTo: itemStack.bottomAnchor, constant: OrbitPagerSettings.labelTopSpacing),
            categoryLabel.topAnchor.constraint(greaterThanOrEqualTo: addStack.bottomAnchor, constant: OrbitPagerSettings.labelTopSpacing),
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
    
    private var borderView = UIView()
    private var itemStack = UIStackView()
    private var addStack = UIStackView()
    private var categoryLabel = UILabel()
    
    private var itemStackViews: [OrbitPagerPageView] {
        itemStack.arrangedSubviews as! [OrbitPagerPageView]
    }
    private var addStackViews: [OrbitPagerPageView] {
        addStack.arrangedSubviews as! [OrbitPagerPageView]
    }
    
    private func displaySelectedInItems() {
        for (index, view) in itemStackViews.enumerated() {
            view.color = (index == pageIndex) ? UIColor.label : UIColor.placeholderText
        }
    }
    private func displaySelectedInAddNew() {
        for (index, view) in addStackViews.enumerated() {
            let selected = pageIndex != nil && index == (pageIndex! - itemCount)
            view.color = selected ? UIColor.label : UIColor.placeholderText
        }
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
