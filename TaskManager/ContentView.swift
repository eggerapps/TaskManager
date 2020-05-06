//
//  ContentView.swift
//  TaskManager
//
//  Created by Jakob Egger on 2020-05-06.
//  Copyright © 2020 eggerapps. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	@State var taskGroups: [TaskGroup] = getSampleData()
	
	var body: some View {
		List(taskGroups) { group in
			VStack(alignment: .leading) {
				Text(group.label).font(.title)
				HStack<AnyView>(alignment: .top) {
					let levels = group.levels
					return AnyView(
						ForEach(levels.indices) { i in
							VStack() {
								ForEach(levels[i]) { task in
									Text(task.label)
								}
							}
						}
					)
				}
			}
		}.frame(maxWidth: .infinity, maxHeight: .infinity)
		
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
