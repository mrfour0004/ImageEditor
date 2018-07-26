//
//  NibLoadable.swift
//
//  Copyright (c) 2016 AliSoftware
//

import UIKit

/// Make your UIView subclasses conform to this protocol when they *are* NIB-based
/// to be able to instantiate them from NIB in a type-safe manner
protocol NibLoadable: AnyObject {
    /// The nib file to use to load a new instance of the View designed in a XIB
    static var nib: UINib { get }
}

extension NibLoadable {
    /// By default, use the nib which have the same name as the name of the class,
    /// and located in the bundle of that class
    static var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }
}

// MARK: - Support for instantiation from nib

extension NibLoadable where Self: UIView {
    /// Returns a `UIView` object instantiated from nib
    ///
    /// - Returns: returns: A `NibLoadable`, `UIView` instance
    static func instantiateFromNib() -> Self {
        guard let view = nib.instantiate(withOwner: nil, options: nil).first as? Self else {
            fatalError("The nib \(nib) expected its root view to be of type \(self)")
        }
        return view
    }
}
