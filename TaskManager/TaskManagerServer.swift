//
//  TaskManagerServer.swift
//  TaskManager
//
//  Created by Jakob Egger on 2020-05-13.
//  Copyright © 2020 eggerapps. All rights reserved.
//

import Foundation

class TaskManagerServer: ObservableObject {
	@Published var taskGroups = [TaskGroup]()
	@Published var serverURL: String = ""
	
	func refresh() throws {
		let connection = try PGConnection(toDatabase: serverURL)
		let result = try connection.executeQuery(#"""
select jsonb_pretty(jsonb_agg(groups)) as groups from (
SELECT
	task_groups.*,
	jsonb_agg(tasks_with_taskruns) tasks
FROM
	task_groups
	LEFT JOIN (
		SELECT
			tasks.*,
			to_jsonb(ARRAY(select depends_on_task_id FROM dependencies where task_id=tasks.id)) dependencies,
			to_jsonb(ARRAY(select taskruns FROM taskruns where task_id=tasks.id)) taskruns
		FROM
			tasks
		GROUP BY tasks.id
	) AS tasks_with_taskruns ON (tasks_with_taskruns.group_id = task_groups.id)
GROUP BY
	task_groups.id
ORDER BY
	task_groups.id DESC
LIMIT 100) as groups;
"""#, withParams: nil)
		let jsonData = result.string(atRow: 0, column: 0)!.data(using: .utf8)!
		let decoder = JSONDecoder()
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
		decoder.dateDecodingStrategy = .formatted(formatter)
		taskGroups = try decoder.decode( 
			[TaskGroup].self, 
			from: jsonData
		)
	}
}
