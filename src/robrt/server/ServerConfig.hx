package robrt.server;

/**
  Notification events.
**/
@:enum abstract NotificationEvent(String) {
    // if the phase (build/export) succeeded
    var success = "success";
    // if the phase (build/export) failed
    var failure = "failure";
}

/**
  Supported notification types.
**/
@:enum abstract NotificationType(String) {
    // GitHub commit statues; defaults to linking to logs
    var github = "github";
    // Slack incomming webhook; by default, only links to the logs on failures
    var slack = "slack";
    // TODO email
}

/**
  Notification handler.

  Send notifications to a given target.
**/
typedef NotificationHandler = {
    // target name
    target : String,
    // filter only some events; defaults to any
    events : Null<Array<NotificationEvent>>,
    // include the logs; defaults are dependent on target type
    logs : Null<Bool>
}

/**
  Notification target.
**/
typedef NotificationTarget = {
    // target type
    type : NotificationType,
    // name for this target; defaults to type
    name : Null<String>,
    // target url
    url : Null<String>
}

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
	destination : {
		?branches : String,
		?pull_requests : String,
		// TODO ?image_creation_log : String,
		?build_log : String
	},
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

