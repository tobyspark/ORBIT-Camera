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

/// Akin to UIPageControl, OrbitPagerView displays a row of dots corresponding to pages. However here, these dots are sectioned into categories, and each section has an 'add new' page at the end.
class OrbitPagerView: UIView {
    /// The page marker image for an item (in UIPageControl, a dot)
    static var itemImage = UIImage(
        systemName: "circle.fill",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 7
        )
    )
    
    /// The add new page marker image
    static var addImage = UIImage(
        systemName: "plus",
        withConfiguration: UIImage.SymbolConfiguration(
            pointSize: 7,
            weight: .black
        )
    )
    
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
        stack.axis = .horizontal
        stack.spacing = 7
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
            while pageStack.arrangedSubviews.count - addNewCount < itemCount {
                pageStack.insertArrangedSubview(itemView(), at: 0)
            }
            while pageStack.arrangedSubviews.count - addNewCount > itemCount {
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
            for (index, view) in pageStack.arrangedSubviews.enumerated() {
                view.tintColor = (index == pageIndex) ? UIColor.label : UIColor.placeholderText
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
        borderView.backgroundColor = UIColor.label
        
        pageStack.axis = .horizontal
        pageStack.spacing = 7
        pageStack.distribution = .fillProportionally
        pageStack.alignment = .center
        pageStack.insertArrangedSubview(addView(), at: 0)
        
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
            borderView.widthAnchor.constraint(equalToConstant: 1),
            
            pageStack.leadingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: 2),
            pageStack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pageStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            
            categoryLabel.leadingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: 2),
            categoryLabel.topAnchor.constraint(equalTo: pageStack.bottomAnchor),
            categoryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            categoryLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        
        let breakableConstraints = [
            pageStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            categoryLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ]
        breakableConstraints.forEach { $0.priority = .init(rawValue: 999) }
        NSLayoutConstraint.activate(breakableConstraints)
    }
    
    private func itemView() -> UIImageView {
        guard let image = OrbitPagerView.itemImage
        else { fatalError("Cannot get dot image") }
        let view = UIImageView(image: image)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }
    
    private func addView() -> UIImageView {
        guard let image = OrbitPagerView.addImage
        else { fatalError("Cannot get add image") }
        let view = UIImageView(image: image)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }
    
    private let addNewCount = 1
    private var borderView = UIView()
    private var pageStack = UIStackView()
    private var categoryLabel = UILabel()
}
