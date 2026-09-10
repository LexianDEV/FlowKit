extends RefCounted
class_name FKProviderLoadResult

var action_providers: Array[FKAction] = []
var condition_providers: Array[FKCondition] = []
var event_providers: Array[FKEvent] = []
var behavior_providers: Array[FKBehavior] = []
var branch_providers: Array[FKBranch] = []
var source: String = ""
var diagnostics: Array[String] = []
var errors: Array[String] = []

func get_total_provider_count() -> int:
	return action_providers.size() + condition_providers.size() + event_providers.size() + \
	behavior_providers.size() + branch_providers.size()