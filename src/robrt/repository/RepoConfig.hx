package robrt.repository;

@:enum abstract FileType(String) {
	var InlineFile = "inline";
	var PathToFile = "path";
}

typedef File = {
	type : FileType,
	data : String
}

typedef PrepareOptions = {
	dockerfile : File
	// TODO other support files
}

typedef BuildOptions = {
	cmds : Array<String>
};

// TODO
typedef ExportOptions = Dynamic;

typedef RepoConfig = {
	?prepare : PrepareOptions,
	?build : BuildOptions,
	?export : ExportOptions
}

