//
//  ContentView.swift
//  TaskManager
//
//  Created by Jakob Egger on 2020-05-06.
//  Copyright © 2020 eggerapps. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	@ObservedObject var server: TaskManagerServer
	@State var selectedTaskId: Int? = nil

	var body: some View {
		VStack {
			HStack {
				TextField("Server URL", text: $server.serverURL)
				Button("Refresh") { 
					do {
						try self.server.refresh()
					}
					catch let error {
						NSApp.presentError(error)
					}
				}
			}.padding()
			List(server.taskGroups) { group in
				VStack(alignment: .leading) {
					Text(group.label).font(.title)
					Spacer()
					HStack<AnyView>(alignment: .top) {
						let levels = group.levels
						return AnyView(
							ForEach(levels.indices, id: \.self) { i in
								VStack(spacing: 10) {
									ForEach(levels[i]) { task in
										TaskView(task: task, selectedTaskId: self.$selectedTaskId)
									}
								}
							}
						)
					}
				}
			}
			
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

struct TaskView: View {
	let task: Task
	
	@Binding var selectedTaskId: Int?
	
	var body: some View {
		Button(action: {
			self.selectedTaskId = self.task.id
		}) {
			ZStack() {
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.foregroundColor(task.taskruns.contains(where: {$0.exit_code == 0}) ? Color.green.opacity(0.2) :
						task.taskruns.contains(where: {$0.exit_code == nil}) ? Color.blue.opacity(0.6):
						!task.taskruns.isEmpty ? Color.yellow.opacity(0.2) :
						task.should_schedule ? Color.blue.opacity(0.2) :
						Color.gray.opacity(0.2))
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				if selectedTaskId == task.id {
					RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(lineWidth: 2).foregroundColor(Color.black.opacity(0.4)).padding(1)
				}
				Text(task.label).foregroundColor(.black).padding()
			}
		}
		.buttonStyle(BorderlessButtonStyle())
		.frame(idealWidth: 300)

	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
		let tm = TaskManagerServer()
		tm.taskGroups = getSampleData()
		return ContentView(server: tm)
    }
}
