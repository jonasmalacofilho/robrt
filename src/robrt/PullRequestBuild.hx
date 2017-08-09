package robrt;

import robrt.Variables;
import js.node.*;

@:build(com.dongxiguo.continuation.Continuation.cpsByMeta("async"))
class PullRequestBuild extends PushBuild {
	var pr:{ number:Int, commit:String };

	function delay(dur:Int, cb:Void->Void)
		js.Node.setTimeout(cb, dur);

	override function fillEnv(env)
	{
		env.push('$Base=${base.branch}');
		env.push('$BaseCommit=${base.commit}');
		env.push('$Head=pull/${pr.number}/head');
		env.push('$HeadCommit=${pr.commit}');
		env.push('$IsPullRequest=1');
		env.push('BASE_BRANCH=${base.branch}');
		env.push('PULL_REQUEST=${pr.number}');
	}

	@async override function prepareRepository()
	{
		log("cloning", [EOpeningRepo]);
		log("waiting 1s for pull/_/head to be available");
		@await delay(1000);
		var cloned = @await openRepo(repo.full_name, buildDir.dir.repository, base, pr, repo.oauth2_token);
		if (!cloned) {
			log("repository error", [ERepositoryError]);
			return false;
		}
		log("merging");
		var err, stdout, stderr = @await ChildProcess.exec('git -C ${buildDir.dir.repository} merge --quiet --commit --no-ff -m "Merge pull request #${pr.number} (at ${pr.commit.substr(0,7)}) into ${base.branch}" pull/${pr.number}/head');
		if (err != null) {
			log('ERR: $err', [EFailedMerge]);
			return false;
		}
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

