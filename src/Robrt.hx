import github.hook.Incoming;
import js.node.*;
import js.node.http.*;
import robrt.Variables;
import robrt.data.RepoConfig;
import robrt.data.ServerConfig;

/**
Robrt: a robot that listens to GitHub events and deploys stuff.

Usage:
  robrt.js listen <port>
  robrt.js -h | --help
  robrt.js --version

Environment variables:
  ROBRT_CONFIG      Alternate path to configuration file
**/
@:rtti
class Robrt
implements com.dongxiguo.continuation.Async {
	static inline var VERSION = "0.0.1-alpha.1";

	static function customTrace(msg:Dynamic, ?p:haxe.PosInfos)
	{
		if (p.customParams != null)
			msg = msg + ',' + p.customParams.join(',');
		msg = '$msg  @${p.fileName}:${p.lineNumber}';
		msg = 'Robrt: $msg';
		js.Node.console.log(msg);
	}

	static function readConfig()
	{
		var path = Sys.getEnv(ServerVariables.ConfigPath);
		if (path == null)
			path = "/etc/robrt.json";
		if (!sys.FileSystem.exists(path) || sys.FileSystem.isDirectory(path))
			throw 'Invalid config path: $path';
		var data = haxe.Json.parse(sys.io.File.getContent(path));
		// TODO validate data
		return (data:ServerConfig);
	}

	static function parseRef(ref:String)
	{
		return ~/^refs\/(heads|tags)\//.replace(ref, "");
	}

	static function shEscape(s:String)
	{
		return "'" + s + "'";
	}

	// TODO handle submodules
	@async static function openRepo(fullName:String, dest:String, base:{ branch:String, commit:String }, ?pr:{ number:Int, commit:String }, ?token:String):Bool
	{
		var url = 'https://github.com/$fullName';
		var cloneUrl = if (token == null) url else StringTools.replace(url, "https://", 'https://$token@');

		// clone and checkout the specified commit
		// for homegeneity with `pr != null` reset the `base.branch` to `base.commit`
		// (this ensures that we're not building some more recent version of the branch by accident)
		var commands = [
			'git clone --quiet --branch ${shEscape(base.branch)} $cloneUrl $dest',
			'git -C $dest checkout --quiet --force ${base.commit}',
			'git -C $dest reset --quiet --hard ${base.commit}'
		];
		if (pr != null) {
			// fetch the pull request head and branch from the specified head commit
			// (this ensures that we're not building some more recent version of the PR by accident)
			commands = commands.concat([
				'git -C $dest fetch --quiet origin pull/${pr.number}/head',
				'git -C $dest branch --quiet pull/${pr.number}/head ${pr.commit}'
			]);
		}
		// cleanup the auth token
		if (token != null)
			commands.push('git -C $dest remote set-url origin $url');

		for (cmd in commands) {
			var err, stdout, stderr = @await ChildProcess.exec(cmd);
			if (err != null) {
				trace('ERROR: $err');
				return false;
			}
		}
		return true;
	}

	@async static function execute(web:Web):Int
	{
		var config = readConfig();
		var hook = Incoming.fromWeb(web);
		var buildId = Crypto.pseudoRandomBytes(4).toString("hex");
		trace('BUILD-ID: $buildId  DELIVERY: ${hook.delivery}');

		var candidates = [];
		for (r in config.repositories) {
			if (r.hook_secret == null || hook.verify(r.hook_secret))
				candidates.push(r);
		}
		if (candidates.length == 0) {
			trace("no signature matches");
			return 404;
		}

		var delivery = hook.parse();
		trace('repository: ${delivery.repository.full_name}');
		trace('event: ${Type.enumConstructor(delivery.event)}');

		candidates = candidates.filter(function (r) return r.full_name == delivery.repository.full_name);
		if (candidates.length == 0) {
			trace("no repository matches");
			return 404;
		}
		trace("repository matches: " + candidates.map(function (r) return r.full_name).join(", "));

		var status = 202;  // accepted
		switch (delivery.event) {
		case GitHubPing(e):
			// done
			status = 200;
		case GitHubPush(e):
			var refName = parseRef(e.ref);

			if (e.deleted) {
				trace('action: deleted $refName');
				// TODO delete
				return status;  // accepted
			}

			trace('action: ${e.created?"created":"pushed"} $refName');
			for (repo in candidates) {
				trace("starting build");

				if (repo.build_options == null) {
					trace("nothing to do, no 'build_options'");
					continue;
				}

				var buildDir = Path.join(repo.build_options.directory, buildId);
				var _ = @await js.npm.Remove.remove(buildDir);
				var ok = @await openRepo(repo.full_name, buildDir, { branch : refName, commit : e.head_commit.id }, repo.oauth2_token);
				if (!ok)
					return status = 500;

				trace("TODO read repo conf, prepare and build");
				status = 501;

				if (repo.export_options == null) {
					trace("nothing to export, no 'export_options'");
					if (status < 300)
						status = 200;
					continue;
				}
				trace("TODO export");
			}
		case GitHubPullRequest(e):
			var status = 202;  // accepted
			switch (e.action) {
			case Assigned, Unassigned, Labeled, Unlabeled, Closed: // NOOP
			case Opened, Synchronize, Reopened:
				trace('base: ${e.pull_request.base.ref}');
				trace('head: ${e.pull_request.head.ref}');
				for (repo in candidates) {
					trace("starting build");

					if (repo.build_options == null) {
						trace("nothing to do, no 'build_options'");
						continue;
					}

					var buildDir = Path.join(repo.build_options.directory, buildId);
					var _ = @await js.npm.Remove.remove(buildDir);

					var ok = @await openRepo(repo.full_name, buildDir, { branch : e.pull_request.base.ref, commit : e.pull_request.base.sha }, { number : e.number, commit : e.pull_request.head.sha }, repo.oauth2_token);
					if (!ok)
						return status = 500;

					trace("TODO check if merge was clean");
					trace("TODO read repo conf, prepare and build");
					status = 501;

					if (repo.export_options == null) {
						trace("nothing to export, no 'export_options'");
						if (status < 300)
							status = 200;
						continue;
					}
					trace("TODO export");
				}
			}
		}
		return status;
	}

	static function main()
	{
		haxe.Log.trace = customTrace;
		var usage = haxe.rtti.Rtti.getRtti(Robrt).doc;
		var options = js.npm.Docopt.docopt(usage, { version : VERSION });

		if (options["listen"]) {

			var port = Std.parseInt(options["<port>"]);
			if (port == null || port < 1 || port > 65355)
				throw 'Invalid port number ${options["<port>"]}';

			var app = Http.createServer(function (req, res) {
				trace('${req.method} ${req.url}');
				var buf = new StringBuf();
				req.on("data", function (data) buf.add(data));
				req.on("end", function () {
					var data = buf.toString();
					var web = {
						getClientHeader : function (name) return req.headers[name.toLowerCase()],
						getPostData : function () return data
					};
					execute(web, function (status) {
						trace(status);
						res.writeHead(status);
						res.end();
					});
				});
			});
			app.listen(port);

		} else {
			throw 'Should not have reached this point;\n$options';
		}
	}
}

