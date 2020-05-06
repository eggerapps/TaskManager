//
//  Models.swift
//  TaskManager
//
//  Created by Jakob Egger on 2020-05-06.
//  Copyright © 2020 eggerapps. All rights reserved.
//

import Foundation


struct TaskGroup: Codable, Identifiable {
	let id: Int
	let label: String
	let tasks: [Task]
	var levels: [[Task]] {
		var dependenciesById = [Int:[Int]]()
		for task in tasks {
			dependenciesById[task.id] = task.dependencies
		}
		func level(taskID: Int) -> Int {
			var l = 0
			if let ids = dependenciesById[taskID] {
				for id in ids {
					l = max(l, level(taskID: id) + 1)
				}
			}
			return l
		}
		var levels = [[Task]]()
		for task in tasks {
			let l = level(taskID: task.id)
			while levels.count <= l {
				levels.append([])
			}
			levels[l].append(task)
		}
		return levels
	}
}

struct Task: Codable, Identifiable {
	let id: Int
	let label: String
	let created: Date
	let taskruns: [TaskRun]
	let dependencies: [Int]
	let should_schedule: Bool
}

struct TaskRun: Codable, Identifiable {
	let id: Int
	let start: Date
	let end: Date?
	let agent_id: Int
	let exit_code: Int?
}

func getSampleData() -> [TaskGroup] {
	let decoder = JSONDecoder()
	let formatter = DateFormatter()
	formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
	decoder.dateDecodingStrategy = .formatted(formatter)
	return try! decoder.decode( 
		[TaskGroup].self, 
		from: sampleData.data(using: .utf8)!
	)
}

let sampleData = #"""
[
    {
        "id": 2,
        "label": "Build 2",
        "tasks": [
            {
                "id": 11,
                "label": "Done",
                "script": "#!/bin/bash\nsay done",
                "created": "2020-05-06T16:07:03.031969+02:00",
                "group_id": 2,
                "priority": 0,
                "taskruns": [
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                    10,
                    9
                ],
                "should_schedule": true
            },
            {
                "id": 8,
                "label": "Say World 1",
                "script": "#!/bin/bash\nsay world",
                "created": "2020-05-05T22:57:36.393482+02:00",
                "group_id": 2,
                "priority": 0,
                "taskruns": [
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                    7
                ],
                "should_schedule": true
            },
            {
                "id": 7,
                "label": "Say Hello",
                "script": "#!/bin/bash\nsay hello",
                "created": "2020-05-05T20:39:24.000117+02:00",
                "group_id": 2,
                "priority": 0,
                "taskruns": [
                    {
                        "id": 13,
                        "end": null,
                        "start": "2020-05-06T16:57:37.157996+02:00",
                        "task_id": 7,
                        "agent_id": 11,
                        "exit_code": null
                    }
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                ],
                "should_schedule": false
            },
            {
                "id": 10,
                "label": "Say World 2",
                "script": "#!/bin/bash\nsay world",
                "created": "2020-05-05T22:57:36.393482+02:00",
                "group_id": 2,
                "priority": 0,
                "taskruns": [
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                    7
                ],
                "should_schedule": true
            },
            {
                "id": 9,
                "label": "Say Bye",
                "script": "#!/bin/bash\nsay bye",
                "created": "2020-05-05T22:57:36.393482+02:00",
                "group_id": 2,
                "priority": 0,
                "taskruns": [
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                    8,
                    10
                ],
                "should_schedule": true
            }
        ],
        "created": "2020-05-06T15:49:36.135622+02:00"
    },
    {
        "id": 1,
        "label": "Build 1",
        "tasks": [
            {
                "id": 5,
                "label": "Say Bye",
                "script": "#!/bin/bash\nsay bye",
                "created": "2020-05-05T22:57:36.393482+02:00",
                "group_id": 1,
                "priority": 0,
                "taskruns": [
                    {
                        "id": 12,
                        "end": "2020-05-06T16:57:35.465774+02:00",
                        "start": "2020-05-06T16:57:30.534356+02:00",
                        "task_id": 5,
                        "agent_id": 11,
                        "exit_code": 0
                    }
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                    4,
                    6
                ],
                "should_schedule": false
            },
            {
                "id": 4,
                "label": "Say World 1",
                "script": "#!/bin/bash\nsay world",
                "created": "2020-05-05T22:57:36.393482+02:00",
                "group_id": 1,
                "priority": 0,
                "taskruns": [
                    {
                        "id": 10,
                        "end": "2020-05-06T16:57:23.847493+02:00",
                        "start": "2020-05-06T16:57:16.4639+02:00",
                        "task_id": 4,
                        "agent_id": 11,
                        "exit_code": 0
                    }
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                    2
                ],
                "should_schedule": false
            },
            {
                "id": 2,
                "label": "Say Hello",
                "script": "#!/bin/bash\nsay hello",
                "created": "2020-05-05T20:39:24.000117+02:00",
                "group_id": 1,
                "priority": 0,
                "taskruns": [
                    {
                        "id": 9,
                        "end": "2020-05-06T16:57:13.279256+02:00",
                        "start": "2020-05-06T16:56:58.035399+02:00",
                        "task_id": 2,
                        "agent_id": 11,
                        "exit_code": 0
                    }
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                ],
                "should_schedule": false
            },
            {
                "id": 6,
                "label": "Say World 2",
                "script": "#!/bin/bash\nsay world",
                "created": "2020-05-05T22:57:36.393482+02:00",
                "group_id": 1,
                "priority": 0,
                "taskruns": [
                    {
                        "id": 11,
                        "end": "2020-05-06T16:57:28.563766+02:00",
                        "start": "2020-05-06T16:57:25.590329+02:00",
                        "task_id": 6,
                        "agent_id": 11,
                        "exit_code": 0
                    }
                ],
                "userinfo": null,
                "toolchains": [
                    "xcode11"
                ],
                "dependencies": [
                    2
                ],
                "should_schedule": false
            }
        ],
        "created": "2020-05-06T15:49:36.135622+02:00"
    }
]
"""#
