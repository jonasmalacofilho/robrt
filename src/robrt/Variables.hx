package robrt;

@:enum abstract ServerVariables(String) to String {
	var ConfigPath = "ROBRT_CONFIG";
}

@:enum abstract BuildVariables(String) to String {
	var RepoPath = "ROBRT_REPOSITORY_DIR";  // /robrt/repository
	var OutPath = "ROBRT_OUTPUT_DIR";  // /robrt/output
	var Head = "ROBRT_HEAD";
	var HeadCommit = "ROBRT_HEAD_COMMIT";
	var Base = "ROBRT_BASE";  // only set for PRs
	var BaseCommit = "BASE_COMMIT";  // only set for PRs
	var IsPullRequest = "ROBRT_IS_PR";
}

