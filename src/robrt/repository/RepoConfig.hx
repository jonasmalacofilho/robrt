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

typedef RepoConfig = {
	?prepare : PrepareOptions,
	?build : BuildOptions,
	?export : Bool
}

