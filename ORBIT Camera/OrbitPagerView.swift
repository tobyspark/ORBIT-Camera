//
//  OrbitPagerView.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 17/04/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import UIKit

struct OrbitPagerSettings {
    /// The page marker image for an item (in UIPageControl, a dot)
    static let itemImage = UIImage(
        systemName: "circle.fill",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 7,
            weight: .black
        )
    )
    
    /// The empty page marker image for an item
    static let emptyImage = UIImage(
        systemName: "circle",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 7,
            weight: .black
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
    enum PageKind {
        case item
        case empty
        case add
    }
    
    /// An array of category tuples, a name, item count and add count triplet
    typealias CategoryPages = [(name: String, pages: [PageKind])]
    
    /// The overall page index currently selected
    var pageIndex: Int = 0 {
        didSet {
            var pageIndexRemaining: Int? = pageIndex
            for categoryView in categoryViews {
                if pageIndexRemaining != nil {
                    if pageIndexRemaining! < categoryView.pages.count
                    {
                        categoryView.pageIndex = pageIndexRemaining!
                        pageIndexRemaining = nil
                    } else {
                        categoryView.pageIndex = nil
                        pageIndexRemaining! -= categoryView.pages.count
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
    func pageIndexes(of kind: PageKind) -> IndexSet {
        var currentCategoryStartIndex = 0
        var indexes: [Int] = []
        for categoryView in categoryViews {
            let addNewIndexes = categoryView.pages.enumerated().reduce(into: [Int](), { (result, x) in
                if x.element == kind { result.append(x.offset)}
            })
            indexes += addNewIndexes.map { $0 + currentCategoryStartIndex}
            currentCategoryStartIndex += categoryView.pages.count
        }
        return IndexSet(indexes)
    }
    
    /// The first add new page index after the currently selected page. Loops back to beginning.
    func pageIndexForNext(_ kind: PageKind) -> Int? {
        let allPages = Array(categoryPages.map({ $0.pages }).joined())
        if pageIndex < allPages.endIndex,
           let addNewIndex = allPages[pageIndex+1..<allPages.endIndex].firstIndex(of: kind)
        {
            return addNewIndex
        }
        if let addNewIndex = allPages[0..<pageIndex].firstIndex(of: kind) {
            return addNewIndex
        }
        return nil
    }
    
    var pageRangeForCurrentCategory: Range<Int>? {
        var categoryStartIndex = 0
        for categoryView in categoryViews {
            if categoryView.pageIndex != nil {
                return categoryStartIndex ..< categoryStartIndex + categoryView.pages.count
            }
            categoryStartIndex += categoryView.pages.count
        }
        return nil
    }
    
    /// The page index corresponding to the category, and index within that category
    func pageIndexFor(category: String, index: Int) -> Int? {
        var categoryStartIndex = 0
        for categoryView in categoryViews {
            if categoryView.name == category {
                assert(index < categoryView.pages.count)
                return categoryStartIndex + index
            }
            categoryStartIndex += categoryView.pages.count
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

    /// The overall page range
    var pageRange: Range<Int> {
        get { 0 ..< pageCount }
    }
    
    /// The total number of pages
    var pageCount: Int {
        get { categoryViews.reduce(0) { $0 + $1.pages.count} }
    }
    
    /// The index within the category corresponding to the overall page index
    func categoryIndex(pageIndex: Int) -> (String, Int)? {
        var categoryStartIndex = 0
        for categoryView in categoryViews {
            let categoryPageIndexes = categoryStartIndex..<categoryStartIndex + categoryView.pages.count
            if categoryPageIndexes.contains(pageIndex) {
                return (categoryView.name, pageIndex - categoryStartIndex)
            }
            categoryStartIndex += categoryView.pages.count
        }
        return nil
    }
    
    /// The categories and corresponding counts to display
    var categoryPages: CategoryPages {
        set {
            // Add or update category views
            for (index, (name, pages)) in newValue.enumerated() {
                if !stack.arrangedSubviews.indices.contains(index) {
                    stack.insertArrangedSubview(OrbitPagerCategoryView(), at: index)
                }
                let categoryView = categoryViews[index]
                categoryView.name = name
                categoryView.pages = pages
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
            categoryViews.map { ($0.name, $0.pages) }
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
    
    var pages: [OrbitPagerView.PageKind] = [] {
        didSet {
            for change in pages.difference(from: oldValue) {
                switch change {
                case let .remove(offset, _, _):
                    let view = pageStack.arrangedSubviews[offset]
                    pageStack.removeArrangedSubview(view)
                    view.removeFromSuperview()
                case let .insert(offset, kind, _):
                    let image: UIImage?
                    switch kind {
                    case .item:
                        image = OrbitPagerSettings.itemImage
                    case .empty:
                        image = OrbitPagerSettings.emptyImage
                    case .add:
                        image = OrbitPagerSettings.addImage
                    }
                    guard let itemImage = image
                    else { fatalError("Cannot get item image") }
                    pageStack.insertArrangedSubview(OrbitPagerPageView(image: itemImage), at: offset)
                }
            }
            for (index, view) in pageStackViews.enumerated() {
                view.color = (index == pageIndex) ? UIColor.label : UIColor.placeholderText
            }
            layoutIfNeeded()
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
    
    private func initCommon() {
        borderView.backgroundColor = UIColor.placeholderText
        
        categoryLabel.font = UIFont.preferredFont(forTextStyle: .body)
        categoryLabel.adjustsFontForContentSizeCategory = true
        
        pageStack.axis = .horizontal
        pageStack.spacing = 0
        pageStack.distribution = .equalCentering
        pageStack.alignment = .center
        
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
