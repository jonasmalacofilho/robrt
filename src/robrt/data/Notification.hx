package robrt.data;

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

