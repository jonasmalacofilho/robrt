package robrt;

@:build(com.dongxiguo.continuation.Continuation.cpsByMeta("async"))
class PullRequestBuild extends Build {
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

	public function new(request, repo, base, pr)
	{
		super(request, repo, base);
		this.pr = pr;
	}
}

