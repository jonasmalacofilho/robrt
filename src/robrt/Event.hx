package robrt;

enum Event {
	ENoBuild(?msg:String);
	EBuildFailure(?msg:String);
	EBuildSuccess(?msg:String);
	ENoExport(?msg:String);
	EExportFailure(?msg:String);
	EExportSuccess(?msg:String);
}

