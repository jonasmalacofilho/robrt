import github.hook.Incoming;
import robrt.Variables;
import robrt.data.RepoConfig;
import robrt.data.ServerConfig;

#if nodejs
import js.node.*;
import js.node.http.*;
#end

class Robrt {
	static var buildId:String;
#if !nodejs
	static var urandom:haxe.io.Input;
#end

	static function customTrace(msg:Dynamic, ?p:haxe.PosInfos)
	{
		if (p.customParams != null)
			msg = msg + ',' + p.customParams.join(',');
		msg = '$msg  @${p.fileName}:${p.lineNumber}';
		if (buildId != null)
			msg = 'Robrt[$buildId]: $msg';
		else
			msg = 'Robrt: $msg';
#if nodejs
		js.Node.console.log(msg);
#else
		Sys.stderr().writeString(msg + "\n");
#end
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

	static function randomBytes(n:Int)
	{
#if nodejs
		return Crypto.randomBytes(n).hxToBytes();
#else
		var b = haxe.io.Bytes.alloc(n);
		var r = 0;
		while (r < n)
			r += urandom.readBytes(b, r, (n - r));
		return b;
#end
	}

	static function execute(web:Web):Int
	{
		var config = readConfig();
		var hook = Incoming.fromWeb(web);
		buildId = randomBytes(4).toHex();
		trace('DELIVERY: ${hook.delivery}');

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

		switch (delivery.event) {
		case GitHubPing(e):
			// NOOP
		case GitHubPush(e):
			var refName = parseRef(e.ref);
			if (e.deleted) {
				trace('action: deleted $refName');
				// TODO delete
				return 202;  // accepted
			}
			if (e.created)
				trace('action: created $refName');
			else
				trace('action: pushed $refName');
			for (repo in candidates) {
				trace("TODO clone, check, checkout, build and deploy");
				return 501;
			}
		case GitHubPullRequest(e):
			switch (e.action) {
			case Assigned, Unassigned, Labeled, Unlabeled, Closed:
				return 202;
			case _:  // nothing
			}
			trace('base: ${e.pull_request.base.ref}');
			trace('head: ${e.pull_request.head.ref}');
			for (repo in candidates) {
				trace("TODO clone, check, checkout, merge , build and deploy");
				return 501;
			}
		}
		return 200;
	}

	static function main()
	{
		haxe.Log.trace = customTrace;
#if nodejs
		var app = Http.createServer(function (req, res) {
			buildId = null;
			trace('${req.method} ${req.url}');
			var buf = new StringBuf();
			req.on("data", function (data) buf.add(data));
			req.on("end", function () {
				var data = buf.toString();
				var web = {
					getClientHeader : function (name) return req.headers[name.toLowerCase()],
					getPostData : function () return data
				};
				var status = execute(web);
				res.writeHead(status);
				res.end();
			});
		});
		app.listen(6667);
#else
		if (neko.Web.isModNeko) {
			if (neko.Web.isTora)
				neko.Web.cacheModule(main);
			buildId = null;
			trace('${neko.Web.getMethod()} ${StringTools.lpad(neko.Web.getURI(), "/", 1)}');
			urandom = sys.io.File.read("/dev/urandom", true);
			try {
				var status = execute(neko.Web);
				trace('return: status $status');
				neko.Web.setReturnCode(status);
			} catch (e:Dynamic) {
				trace("ERROR: uncaught exception");
				trace('Exception: $e\n${haxe.CallStack.toString(haxe.CallStack.exceptionStack())}');
				try neko.Web.setReturnCode(500) catch (e:Dynamic) {}
			}
			urandom.close();
		} else {
			readConfig();  // TODO cli interface for validating config files
		}
#end
	}
}

