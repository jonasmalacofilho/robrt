package robrt;

@:enum abstract ServerVariables(String) to String {
	var ConfigPath = "ROBRT_CONFIG";
}

@:enum abstract BuildVariables(String) to String {
	var RepoPath = "ROBRT_REPOSITORY_DIR";  // /robrt/repository
	var OutPath = "ROBRT_OUTPUT_DIR";  // /robrt/output
}

