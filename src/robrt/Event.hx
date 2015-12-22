package robrt;

@:enum abstract Event(String) {
	var EStarted = "started";

	var EOpeningRepo = "opening-repo";
	var ERepositoryError = "repository-error";
	var EFailedMerge = "failed-merge";

	var EPreparing = "preparing";
	var ENoRepoConf = "no-repo-conf";
	var EInvalidRepoConf = "invalid-repo_conf";
	var ENoRepoPrepare = "no-repo-prepare";
	var EPrepareError = "prepare-error";

	var EBuilding = "building";
	var ENoBuild = "no-build";
	var ENoRepoBuild = "no-repo-build";
	var EBuildError = "build-error";
	var EBuildFailure = "build-failure";

	var EBuildSuccess = "build-success";
	var EExporting = "exporting";
	var ENoExport = "no-export";
	var EExportError = "export-error";

	var EExportSuccess = "export-success";
	var EDone = "done";
}

