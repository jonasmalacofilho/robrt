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

	override function makeTags()
		tags = [ "pr_number" => Std.string(pr.number), "build_id" => request.buildId ];

	public function new(request, repo, base, pr)
	{
		this.pr = pr;
		super(request, repo, base);
	}
}

