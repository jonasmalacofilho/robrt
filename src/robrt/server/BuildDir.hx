package robrt.server;

typedef BuildDir = {
	dir : {
		base : String,
		repository : String,
		to_export : String,
	},
	file : {
		docker_build : String,
		// TODO clone log
		// TODO docker_build_log
		robrt_build_log : String
		// TODO robrt_export_log
	}
}

