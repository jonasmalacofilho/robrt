package robrt;

import github.hook.Incoming;
import js.node.*;
import js.node.http.*;
import robrt.Variables;
import robrt.repository.RepoConfig;
import robrt.server.BuildDir;
import robrt.server.ServerConfig;

@:build(com.dongxiguo.continuation.Continuation.cpsByMeta("async"))
class IncomingRequest {
	public var buildId(default,null):String;
	var config:ServerConfig;

	function new(config)
	{
		buildId = Crypto.pseudoRandomBytes(4).toString("hex");
		this.config = config;
	}

	static function parsePushRef(ref:String)
	{
		return ~/^refs\/(heads|tags)\//.replace(ref, "");
	}

	@async function execute(web:Web):Int
	{
		var hook:Incoming = try {
			Incoming.fromWeb(web);
		} catch (e:Dynamic) {
			// TODO try to return a more informative status, such as 400
			// (missing header, bad json), 405 (method not allowed), 415
			// (bad content-type) or 500 (other reasons)
			log('Failure to interpret: $e');
			return 500;
		}

		log('DELIVERY: ${hook.delivery}');

		var candidates = [];
		for (r in config.repositories) {
			if (r.hook_secret == null || hook.verify(r.hook_secret))
				candidates.push(r);
		}
		if (candidates.length == 0) {
			log("no signature matches");
			return 404;
		}

		var delivery = hook.parse();
		log('repository: ${delivery.repository.full_name}');
		log('event: ${Type.enumConstructor(delivery.event)}');

		candidates = candidates.filter(function (r) return r.full_name == delivery.repository.full_name);
		if (candidates.length == 0) {
			log("no repository matches");
			return 404;
		}
		log("repository matches: " + candidates.map(function (r) return r.full_name).join(", "));

		switch (delivery.event) {
		case GitHubPing(e):  // done, NOOP
		case GitHubPush(e):
			var branch = parsePushRef(e.ref);
			var base = { branch : branch, commit : e.head_commit.id };

			if (e.deleted) {
				log('action: deleted $branch');
				log("TODO delete");
				return 204;
			}

			log('action: ${e.created?"created":"pushed"} $branch');
			for (repo in candidates) {
				var build = new Build(this, repo, base);
				var status = @await build.run();
				if (status != 200)
					return status;
			}
			return 200;
		case GitHubPullRequest(e):
			switch (e.action) {
			case Assigned, Unassigned, Labeled, Unlabeled, Closed: // NOOP
			case Opened, Synchronize, Reopened:
				log('base: ${e.pull_request.base.ref}');
				log('head: ${e.pull_request.head.ref}');
				var base = { branch : e.pull_request.base.ref, commit : e.pull_request.base.sha };
				var pr = { number : e.number, commit : e.pull_request.head.sha };
				for (repo in candidates) {
					var build = new PullRequestBuild(this, repo, base, pr);
					var status = @await build.run();
					if (status != 200)
						return status;
				}
				return 200;
			}
		}
		return 204;
	}

	public function log(msg:Dynamic, ?p:haxe.PosInfos)
	{
		Robrt.ctrace('[$buildId] $msg', p);
	}

	public static function handleRequest(config:ServerConfig, req:IncomingMessage, res:ServerResponse)
	{
		var r = new IncomingRequest(config);
		trace('${req.method} ${req.url} -> [${r.buildId}]');
		var buf = new StringBuf();
		req.on("data", function (data) buf.add(data));
		req.on("end", function () {
			var data = buf.toString();
			var web = {
				getClientHeader : function (name) return req.headers[name.toLowerCase()],
				getMethod : function () return req.method,
				getPostData : function () return data
			};
			r.execute(web, function (status) {
				r.log('Returnig $status (${Http.STATUS_CODES.get(Std.string(status))})');
				res.writeHead(status);
				res.end();
			});
		});
	}
}

