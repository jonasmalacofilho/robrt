package robrt;

@:build(com.dongxiguo.continuation.Continuation.cpsByMeta("async"))
class PullRequestBuild extends PushBuild {
	var pr:{ number:Int, commit:String };

	@async override function prepareRepository()
	{
		log("cloning");
		var cloned = @await openRepo(repo.full_name, buildDir.dir.repository, base, repo.oauth2_token);
		if (!cloned)
			return false;
		// TODO merge
		return true;
	}

	override function getExportPath()
		return repo.export_options.destination.pull_requests;

	public function new(request, repo, base, pr)
	{
		super(request, repo, base);
		this.pr = pr;
		tags["pr_number"] = Std.string(pr.number);
		tags["pr_commit"] = pr.commit;
		tags["pr_commit_short"] = pr.commit.substr(0, 7);
		notifier = new robrt.Notifier.NotifierHub(tags, repo, base, pr);
	}
}

