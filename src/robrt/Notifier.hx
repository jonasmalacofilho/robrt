package robrt;

import robrt.Event;
import robrt.server.ServerConfig;
import js.node.*;

interface Notifier {
	public function notify(event:Event, cb:js.Error->Notifier->Void):Void;
}

private class BaseNotifier implements Notifier {
	var repo:Repository;
	var base:{ branch:String, commit:String };
	var pr:Null<{ number:Int, commit:String }>;

	var tags:TagMap;
	var customPayload:Null<CustomPayload>;

	function expand(p:Dynamic):Dynamic
	{
		return switch Type.typeof(p) {
		case TNull, TInt, TFloat, TBool: p;
		case TClass(c) if (Type.getClassName(c) == "String"):
			~/\$([a-z_]+)/g.map(p, function (r) {
				var key = r.matched(1);
				if (tags.exists(key))
					return tags[key];
				else
					return r.matched(0);
			});
		case TClass(c) if (Type.getClassName(c) == "Array"):
			[ for (i in (p:Array<Dynamic>)) expand(i) ];
		case TObject:
			var q:Dynamic = {};
			for (f in Reflect.fields(p))
				Reflect.setField(q, expand(f), expand(Reflect.field(p, f)));
			q;
		case _:
			throw 'Unexpected $p';
		}
	}

	function getPayload(event:Event):Array<Dynamic>
	{
		if (customPayload == null)
			return [];
		var ps = pr == null ? customPayload.branch_builds : customPayload.pull_requests;
		return Lambda.filter(ps, function (i) return Lambda.find(i.events, function (e) return e == event) != null)
				.map(function (i) return expand(i.payload));
	}

	public function notify(event:Event, cb:js.Error->Notifier->Void)
	{
		cb(new js.Error("Not implemented"), null);
	}

	public function new(repo, base, pr, tags, customPayload)
	{
		this.repo = repo;
		this.base = base;
		this.pr = pr;
		this.tags = tags;
		this.customPayload = customPayload;
	}
}

class GitHubNotifier extends BaseNotifier {
	var context:String;
	var url:String;
	var reqOpts:Http.HttpRequestOptions;

	var queue:Array<{ event:Event, cb:js.Error->Notifier->Void }>;
	var running:Bool;

	function pop(?pos:haxe.PosInfos) {
		trace('popping (source was ${pos.fileName}:${pos.lineNumber})');
		var next = queue.shift();
		if (next == null) {
			trace("no more items in queue");
			running = false;
			return;
		}

		var event = next.event;
		var cb = next.cb;
		trace('dequeue "$event"');

		var ps = getPayload(event);
		if (ps.length == 0) {
			trace('nothing to do, will pop again immediatly (event was "$event")');
			pop();
			return;
		}

		for (p in ps) {
			if (p.context == null)
				p.context = "Robrt";

			var json = haxe.Json.stringify(p);
			function onRes(res:js.node.http.IncomingMessage) {
				if (res.statusCode >= 200 && res.statusCode < 300) {
					trace('will pop again only after 500ms (event was "$event")');
					js.Node.setTimeout(function () pop(), 500);
					res.resume();
				} else {
					var buf = new StringBuf();
					res.on("data", function (chunk:String) buf.add(chunk));
					res.on("end", function (err) {
						var err = new js.Error('github: ${res.statusCode} (${buf.toString().split("\n").join(" ")})');
						trace('will pop again only after 10000ms (event was "$event")');
						js.Node.setTimeout(function () pop(), 10000);
						cb(err, res.statusCode != 403 ? this : null);
					});
				}
			}
			var req = Https.request(untyped reqOpts, onRes);  // FIXME remove untyped
			req.end(json);
		}
	}

	override public function notify(event:Event, cb:js.Error->Notifier->Void)
	{
		if (url == null)
			return;
		trace('enqueue "$event"');
		queue.push({ event:event, cb:cb });
		if (!running) {
			trace('immediatly popping');
			running = true;
			pop();
		}
	}

	public function new(repo:Repository, base, pr, tags, customPayload, ?context:String, ?url:String)
	{
		queue = [];
		if (context == null)
			context = "Robrt";
		if (url == null) {
			var sha = pr != null ? pr.commit : base.commit;
			url = 'https://api.github.com/repos/${repo.full_name}/statuses/$sha?access_token=${repo.oauth2_token}';
		}
		this.context = context;
		this.url = url;
		super(repo, base, pr, tags, customPayload);

		if (url != null) {
			var _url = Url.parse(url);
			reqOpts = {
				hostname : _url.hostname,
				path : _url.path,
				protocol : _url.protocol,
				port : 443,
				method : "POST",
				headers : { "User-Agent" : "Robrt" }
			}
		}
	}
}

class SlackNotifier extends BaseNotifier {
	var url:String;
	var reqOpts:Http.HttpRequestOptions;

	override public function notify(event:Event, cb:js.Error->Notifier->Void)
	{
		var ps = getPayload(event);
		if (ps.length == 0)
			return;

		for (p in ps) {
			var json = haxe.Json.stringify(p);
			function onRes(res:js.node.http.IncomingMessage) {
				if (res.statusCode == 200) {
					res.resume();
				} else {
					var buf = new StringBuf();
					res.on("data", function (chunk:String) buf.add(chunk));
					res.on("end", function (err) {
						var err = new js.Error('slack: ${res.statusCode} (${buf.toString().split("\n").join(" ")})');
						cb(err, res.statusCode != 403 ? this : null);
					});
				}
			}
			var req = Https.request(untyped reqOpts, onRes);  // FIXME remove untyped
			req.end(json);
		}
	}

	public function new(url, repo, base, pr, tags, customPayload)
	{
		if (url == null) throw "Slack requires an url";
		this.url = url;
		super(repo, base, pr, tags, customPayload);

		var _url = Url.parse(url);
		reqOpts = {
			hostname : _url.hostname,
			path : _url.path,
			protocol : _url.protocol,
			port : 443,
			method : "POST",
			headers : { "User-Agent" : "Robrt" }
		}
	}
}

class NotifierHub extends BaseNotifier {
	var notifiers:Array<{ name:String, notifier:Notifier }>;

	override public function notify(event:Event, cb:js.Error->Notifier->Void)
	{
		for (n in notifiers)
			n.notifier.notify(event, cb);
	}

	public function new(tags, repo, base, ?pr, ?notifiers)
	{
		super(repo, base, pr, tags, null);

		if (notifiers != null) {
			this.notifiers = notifiers;
		} else if (repo.notification_targets != null) {
			this.notifiers = [];
			for (t in repo.notification_targets) {
				var name = t.name != null ? t.name : t.type;
				var notifier = switch t.type {
				case Slack:
					new SlackNotifier(t.url, repo, base, pr, tags, t.customPayload);
				case GitHub:
					new GitHubNotifier(repo, base, pr, tags, t.customPayload);
				}
				if (notifier != null)
					this.notifiers.push({ name:name, notifier:notifier });
			}
		} else {
			this.notifiers = [];
		}
	}
}

