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
    /// The page marker image
    static var dotImage = UIImage(
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
            for categoryView in stack.arrangedSubviews as! [OrbitPagerCategoryView] {
                if pageIndexRemaining != nil {
                    if pageIndexRemaining! < categoryView.totalCount
                    {
                        categoryView.pageIndex = pageIndexRemaining!
                        pageIndexRemaining = nil
                    } else {
                        categoryView.pageIndex = nil
                        pageIndexRemaining! -= categoryView.totalCount
                    }
                } else {
                    categoryView.pageIndex = nil
                }
            }
        }
    }
    
    /// The page index currently selected by category-index and page-index-within-category
    // TODO: this
    
    /// The categories and corresponding counts to display
    var categoryCounts: CategoryCounts {
        set {
            // Add or update category views
            for (index, (name, count)) in newValue.enumerated() {
                if !stack.arrangedSubviews.indices.contains(index) {
                    stack.insertArrangedSubview(OrbitPagerCategoryView(), at: index)
                }
                let categoryView = stack.arrangedSubviews[index] as! OrbitPagerCategoryView
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
            let categoryViews = stack.arrangedSubviews as! [OrbitPagerCategoryView]
            return categoryViews.map { ($0.name, $0.itemCount)}
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
            while dotStack.arrangedSubviews.count - addNewCount < itemCount {
                dotStack.insertArrangedSubview(dotView(), at: 0)
            }
            while dotStack.arrangedSubviews.count - addNewCount > itemCount {
                let view = dotStack.arrangedSubviews[0]
                dotStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            layoutIfNeeded()
        }
    }
    
    var totalCount: Int {
        get {
            itemCount + addNewCount
        }
    }
    
    var pageIndex: Int? {
        didSet {
            for (index, view) in dotStack.arrangedSubviews.enumerated() {
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
        
        dotStack.axis = .horizontal
        dotStack.spacing = 7
        dotStack.distribution = .fillProportionally
        dotStack.alignment = .center
        dotStack.insertArrangedSubview(addView(), at: 0)
        
        categoryLabel.lineBreakMode = .byClipping
        
        translatesAutoresizingMaskIntoConstraints = false
        borderView.translatesAutoresizingMaskIntoConstraints = false
        dotStack.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(borderView)
        addSubview(dotStack)
        addSubview(categoryLabel)
        
        let constraints = [
            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.topAnchor.constraint(equalTo: topAnchor),
            borderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            borderView.widthAnchor.constraint(equalToConstant: 1),
            
            dotStack.leadingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: 2),
            dotStack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            dotStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            
            categoryLabel.leadingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: 2),
            categoryLabel.topAnchor.constraint(equalTo: dotStack.bottomAnchor),
            categoryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            categoryLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        
        let breakableConstraints = [
            dotStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            categoryLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ]
        breakableConstraints.forEach { $0.priority = .init(rawValue: 999) }
        NSLayoutConstraint.activate(breakableConstraints)
    }
    
    private func dotView() -> UIImageView {
        guard let image = OrbitPagerView.dotImage
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
    private var dotStack = UIStackView()
    private var categoryLabel = UILabel()
}
