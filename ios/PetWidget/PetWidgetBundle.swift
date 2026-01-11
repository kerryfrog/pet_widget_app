//
//  PetWidgetBundle.swift
//  PetWidget
//
//  Created by 이다솜 on 1/11/26.
//

import WidgetKit
import SwiftUI

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget {
        PetWidget()
        PetWidgetControl()
        PetWidgetLiveActivity()
    }
}
