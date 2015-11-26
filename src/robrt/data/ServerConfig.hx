package robrt.data;

import robrt.data.Notification;

typedef Filter = {
	// include only some refs; defaults to all
	?refs : Array<String>,
	// include pull requests; defaults to true
	?pull_requests : Bool
}

typedef BuildOptions = {
	// base build directory on the server filesystem
	directory : String,
	// only build some refs; defaults to all
	?filter : Filter,
	// notify this targets
	?notify : Array<NotificationHandler>
}

typedef ExportOptions = {
	// export destination on the server filesystem
	destination : String,
	// only export some refs; defaults to all
	?filter : Filter,
	// notify this targets
	?notify : Array<NotificationHandler>
}

/**
  Repository.
**/
typedef Repository = {
    // repository full name: foo/bar
    full_name : String,
    // hook secret; only accept GitHub deliveries signed with this
    ?hook_secret : String,
    // oauth2_token; use to clone private repos and to post commit statuses
    ?oauth2_token : String,
    // build options; if missing, build will not run
    ?build_options : BuildOptions,
    // export options; if missing, export will not run
    ?export_options : ExportOptions,
    // outbound hook configuration
    ?notification_targets : Array<NotificationTarget>
}

/**
  Server configuration.
**/
typedef ServerConfig = {
    repositories : Array<Repository>
}

