//
//  StoryboardLoadable.swift
//  Rakumi
//
//  Created by Liang, KaiChih on 09/03/2018.
//  Copyright © 2018 Liang, KaiChih. All rights reserved.
//

import UIKit

/// Make your UIViewController subclasses conform to this protocol when they **are** storyboard-based.
protocol StoryboardLoadable: AnyObject {
    static var storyboard: UIStoryboard { get }
}

extension StoryboardLoadable where Self: UIViewController {
    static var storyboard: UIStoryboard {
        return UIStoryboard(name: String(describing: self), bundle: nil)
    }

    static func instantiateFromStoryboard() -> Self {
        return storyboard.instantiateViewController(withIdentifier: String(describing: self)) as! Self
    }
}
