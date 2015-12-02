package robrt.server;

typedef BuildDir = {
	dir : {
		base : String,
		repository : String,
		to_export : String,
	},
	file : {
		docker_build : String
	}
}

