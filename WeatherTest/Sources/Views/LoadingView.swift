//
//  LoadingView.swift
//  WeatherTest
//
//  Created by Martin Albrecht on 15.10.20.
//

import UIKit

@IBDesignable
class LoadingView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: .init(String(describing: type(of: self))), bundle: bundle)
        let mainView = nib.instantiate(withOwner: nil, options: nil).last as! UIView
            
        mainView.frame = bounds
        addSubview(mainView)
    }
}
