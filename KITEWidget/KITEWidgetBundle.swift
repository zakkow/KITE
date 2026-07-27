//
//  KITEWidgetBundle.swift
//  KITEWidget
//
//  Created by Apple on 7/16/26.
//

import WidgetKit
import SwiftUI

@main
struct KITEWidgetBundle: WidgetBundle {
    var body: some Widget {
        KITEWidget()
        KITEWidgetControl()
        KITEWidgetLiveActivity()
    }
}
