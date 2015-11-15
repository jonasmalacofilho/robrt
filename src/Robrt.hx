import robrt.Variables;
import robrt.data.RepoConfig;
import robrt.data.ServerConfig;
import github.hook.Incoming;
import neko.Web;

class Robrt {
	static var id:String;

	static function customTrace(msg:Dynamic, ?p:haxe.PosInfos)
	{
		if (p.customParams != null)
			msg = msg + ',' + p.customParams.join(',');
		msg = '$msg  @${p.fileName}:${p.lineNumber}\n';
		if (id != null)
			msg = '[$id]: $msg';
		Sys.stderr().writeString(msg);
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

	static function execute():Int
	{
		var config = readConfig();
		var hook = Incoming.fromWeb();
		id = hook.delivery;

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

		for (r in candidates) {
			switch (delivery.event) {
			case GitHubPing(e):  // NOOP
			case GitHubPush(e):  // TODO clone, build and deploy
			case GitHubPullRequest(e):  // TODO clone, apply, build and deploy
			}
		}
		return 200;
	}

	static function main()
	{
		haxe.Log.trace = customTrace;
		if (Web.isModNeko) {
			if (Web.isTora)
				Web.cacheModule(main);
			try {
				Web.setReturnCode(execute());
			} catch (e:Dynamic) {
				trace("ERROR: uncaught exception");
				trace('Exception: $e');
				trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
				try Web.setReturnCode(500) catch (e:Dynamic) {}
			}
		} else {
			readConfig();  // TODO cli interface for validating config files
		}
	}
}

