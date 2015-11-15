package github.hook;

typedef Url = String;
typedef DateString = String;
typedef ShortRef = String;  // master, development
typedef LongRef = String;  // /refs/heads/master, /refs/heads/development

typedef User = {
	login : String,
	id : Int,
	avatar_url : String,
	gravatar_id : String,
	type : String,
	site_admin : Bool
	// more urls
}

typedef ShortUser = {
	name : String,	// this actually is the username
	email : String
}

typedef GitUser = {
	name : String,
	email : String,
	username : String
}

typedef BaseRepository = {
	id : Int,
	name : String,
	full_name : String,
	// private : Bool,
	html_url : Url,
	description : String,
	fork : Bool,
	created_at : DateString,
	updated_at : DateString,
	pushed_at : DateString,
	clone_url : Url,
	homepage : Null<String>,
	size : Int,
	language : Null<String>,
	has_issues : Bool,
	has_downloads : Bool,
	has_wiki : Bool,
	has_pages : Bool,
	forks_count : Int,
	mirror_url : Null<Url>,
	forks : Int,
	default_branch : ShortRef
}

typedef CommonRepository = {
	> BaseRepository,
	owner : User
}

typedef PushRepository = {
	> BaseRepository,
	owner : ShortUser,
}

typedef Commit = {
	id : String,
	distinct : Bool,
	message : String,
	timestamp : String,
	url : Url,
	author : User,
	committer : User,
	added : Array<String>,
	removed : Array<String>,
	modified : Array<String>
}

typedef Head = {
	label : String,
	ref : String,
	sha : String,
	user : User,
	repo : CommonRepository
}

@:enum abstract PullRequestAction(String) {
	var Assigned = "assigned";
	var Unassigned = "unassigned";
	var Labeled = "labeled";
	var Unlabeled = "unlabeled";
	var Opened = "opened";
	var Closed = "closed";
	var Reopened = "reopened";
	var Synchronize = "synchronize";
}

@:enum abstract PullRequestState(String) {
	var Open = "assigned";
	var Closed = "unassigned";
}

typedef PullRequest = {
	id : Int,
	html_url : Url,
	patch_url : Url,
	statuses_url : Url,
	number : Int,
	state : PullRequestState,
	locked : Bool,
	title : String,
	user : User,
	body : String,
	created_at : DateString,
	updated_at : DateString,
	closed_at : DateString,
	merged_at : DateString,
	merge_commit_sha : String,
	// assignee
	// milestone
	head : Head,
	base : Head,
	merged : Bool,
	mergeable : Null<Bool>,  // null => hasn't been computed yet, give it a few moments
	merged_by : Null<User>,
	comments : Int,
	review_comments : Int,
	commits : Int,
	additions : Int,
	deletions : Int,
	changed_files : Int
	// more urls
}

typedef BaseEvent = {
	repository : CommonRepository,
	sender : User
}

typedef PingEvent = {
	> BaseEvent,
	zen : String,
	hook_id : Int,
	hook : github.hook.Config,
}

typedef PushEvent = {
	ref : String,
	before : String,
	after : String,
	created : Bool,
	deleted : Bool,
	forced : Bool,
	base_ref : Dynamic,
	compare : Url,
	commits : Array<Commit>,
	head_commit : Commit,
	pusher : ShortUser,
	repository : PushRepository,
	sender : User
}

typedef PullRequestEvent = {
	> BaseEvent,
	action : PullRequestAction,
	number : Int,
	pull_request : PullRequest
}

enum Event {
	GitHubPing(e:PingEvent);
	GitHubPush(e:PushEvent);
	GitHubPullRequest(e:PullRequestEvent);
}

