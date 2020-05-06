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
				Spacer()
				HStack<AnyView>(alignment: .top) {
					let levels = group.levels
					return AnyView(
						ForEach(levels.indices) { i in
							VStack(spacing: 10) {
								ForEach(levels[i]) { task in
									TaskView(task: task)
								}
							}
						}
					)
				}
			}
		}.frame(maxWidth: .infinity, maxHeight: .infinity)
		
	}
}

struct TaskView: View {
	let task: Task
	
	var body: some View {
		Text(task.label)
			.padding()
			.background(
				task.taskruns.contains(where: {$0.exit_code == 0}) ? Color.green.opacity(0.2) :
					task.taskruns.contains(where: {$0.exit_code == nil}) ? Color.blue.opacity(0.6):
					!task.taskruns.isEmpty ? Color.yellow.opacity(0.2) :
					task.should_schedule ? Color.blue.opacity(0.2) :
					Color.gray.opacity(0.2))
			.cornerRadius(5)
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
