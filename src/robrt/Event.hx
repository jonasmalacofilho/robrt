package robrt;

@:enum abstract Event(String) {
	var EStarted = "started";

	var EPreparing = "preparing";
	var ENoPrepare = "no-prepare";
	var ERepositoryError = "repository-error";
	var EPrepareError = "prepare-error";

	var EBuilding = "building";
	var ENoBuild = "no-build";
	var EBuildError = "build-error";
	var EBuildFailure = "build-failure";

	var EBuildSuccess = "build-success";
	var EExporting = "exporting";
	var ENoExport = "no-export";
	var EExportError = "export-error";

	var EExportSuccess = "export-success";
	var EDone = "done";
}

